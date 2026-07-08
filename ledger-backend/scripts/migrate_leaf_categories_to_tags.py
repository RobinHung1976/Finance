import argparse
import os
import sys
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.database import SessionLocal
from app.models import Budget, Category, Tag, Transaction, TransactionTag


def get_depth(category: Category, by_id: dict) -> int:
    depth = 1
    node = category
    while node.parent_id:
        node = by_id[node.parent_id]
        depth += 1
    return depth


def run(execute: bool) -> None:
    db: Session = SessionLocal()
    try:
        categories = db.execute(select(Category)).scalars().all()
        by_id = {c.id: c for c in categories}
        children_count = defaultdict(int)
        for c in categories:
            if c.parent_id:
                children_count[c.parent_id] += 1

        candidates = []
        skipped_has_children = []
        for c in categories:
            if get_depth(c, by_id) < 3:
                continue
            if children_count.get(c.id, 0) > 0:
                skipped_has_children.append(c)
            else:
                candidates.append(c)

        if skipped_has_children:
            print("⚠️ 以下節點 depth>=3 但自己還有子分類,結構比預期複雜,已跳過(需人工確認):")
            for c in skipped_has_children:
                print(f"   - {c.name} (id={c.id})")
            print()

        if not candidates:
            print("沒有符合條件的分類(depth>=3 的葉節點),不需要遷移。")
            return

        groups = defaultdict(list)
        for c in candidates:
            groups[(c.household_id, c.name.strip(), c.type)].append(c)

        print(f"共發現 {len(candidates)} 個待轉換分類節點,分成 {len(groups)} 個消費品項群組:\n")

        total_tx_affected = 0
        for (household_id, name, type_), leaves in groups.items():
            group_tx_count = 0
            parent_names = set()
            for leaf in leaves:
                parent = by_id.get(leaf.parent_id)
                parent_names.add(parent.name if parent else "?")
                group_tx_count += db.query(Transaction).filter(Transaction.category_id == leaf.id).count()
            total_tx_affected += group_tx_count
            print(f"  [{type_.value}] 「{name}」 <- {' / '.join(parent_names)} "
                  f"(節點數:{len(leaves)}, 交易筆數:{group_tx_count})")

        print(f"\n預計影響交易筆數合計:{total_tx_affected}")

        if not execute:
            print("\n[dry-run] 未實際寫入,加上 --execute 才會真正執行。")
            return

        deleted_count = 0
        skipped_budget_refs = []

        for (household_id, name, type_), leaves in groups.items():
            tag = db.execute(
                select(Tag).where(Tag.household_id == household_id, Tag.name == name)
            ).scalar_one_or_none()
            if tag is None:
                tag = Tag(household_id=household_id, name=name)
                db.add(tag)
                db.flush()

            for leaf in leaves:
                parent_id = leaf.parent_id
                if parent_id is None:
                    print(f"  ⚠️ 跳過:「{leaf.name}」沒有父層,不應該發生 (id={leaf.id})")
                    continue

                txs = db.query(Transaction).filter(Transaction.category_id == leaf.id).all()
                for tx in txs:
                    exists = db.query(TransactionTag).filter(
                        TransactionTag.transaction_id == tx.id, TransactionTag.tag_id == tag.id
                    ).first()
                    if not exists:
                        db.add(TransactionTag(transaction_id=tx.id, tag_id=tag.id))
                    tx.category_id = parent_id
                db.flush()

                budget_ref_count = db.query(Budget).filter(Budget.category_id == leaf.id).count()
                if budget_ref_count > 0:
                    skipped_budget_refs.append((leaf.name, leaf.id, budget_ref_count))
                    continue

                db.delete(leaf)
                deleted_count += 1

        db.commit()
        print(f"\n✅ 遷移完成:{len(groups)} 個消費品項群組,{total_tx_affected} 筆交易已改掛消費品項並指向父層分類,"
              f"刪除 {deleted_count} 個舊分類節點。")

        if skipped_budget_refs:
            print("\n⚠️ 以下分類節點因被 Budget 引用而保留(未刪除),請人工確認是否需要調整預算設定:")
            for name, cid, count in skipped_budget_refs:
                print(f"   - {name} (id={cid}, 被 {count} 筆預算引用)")

    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="把第三層以下分類節點轉換成消費品項(Tag)")
    parser.add_argument("--execute", action="store_true", help="實際執行(預設為 dry-run 預覽)")
    args = parser.parse_args()
    run(execute=args.execute)

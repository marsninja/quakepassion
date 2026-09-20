"""Typed inventory slots shared by player and non-player actors."""
edge InventorySlot {}
node Inventory {}
node ItemStack {
    has kind: str,
        quantity: int = 0,
        capacity: int = 1;
}

walker AdjustInventory {
    has kind: str,
        amount: int,
        capacity: int = 1,
        accepted: int = 0;

    can begin with Inventory entry {
        slots = [
            slot
            for slot in [here->:InventorySlot:->][?:ItemStack]
            if slot.kind == self.kind
        ];
        if not slots and self.amount > 0 and self.capacity > 0 {
            slot = ItemStack(kind=self.kind, capacity=self.capacity);
            here +>:InventorySlot:+> slot;
            slots.append(slot);
        }
        visit slots;
    }

    can adjust with ItemStack entry {
        old = here.quantity;
        here.quantity = min(here.capacity, max(0, here.quantity + self.amount));
        self.accepted += here.quantity - old;
    }
}

def quantity(inventory: Inventory, kind: str) -> int {
    for slot in [inventory->:InventorySlot:->][?:ItemStack] {
        if slot.kind == kind {
            return slot.quantity;
        }
    }
    return 0;
}

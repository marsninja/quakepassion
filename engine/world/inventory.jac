"""Typed inventory slots shared by player and non-player actors."""
edge InventorySlot: Inventory --> ItemStack {}
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


walker CopyInventory {
    has result: Inventory = Inventory(), skip_keys: bool = False;
    can start with Inventory entry { visit [here->:InventorySlot:->]; }
    can copy with ItemStack entry {
        # A new unit also forgets Q2 cross-level trigger flags (ExitLevel).
        if self.skip_keys and (here.kind.startswith("key_") or here.kind == "unit_flags") { return; }
        self.result spawn AdjustInventory(kind=here.kind, amount=here.quantity, capacity=here.capacity);
    }
}


def key_summary(inventory: Inventory) -> str {
    keys: list[str] = [];
    for item in [inventory->:InventorySlot:->][?:ItemStack] {
        if item.kind.startswith("key_") and item.quantity > 0 {
            keys.append(item.kind[4:].replace("_", " ") + (" x" + str(item.quantity) if item.quantity > 1 else ""));
        }
    }
    return "Keys: " + ", ".join(keys) if keys else "";
}

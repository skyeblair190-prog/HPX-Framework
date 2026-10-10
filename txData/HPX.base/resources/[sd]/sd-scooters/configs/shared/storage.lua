-- The storage box works like a car trunk: "Open storage" lifts the lid and opens a small stash,
-- and closing the stash drops the lid shut.
-- Only scooters with the "Storage box" extra (catalogue id "delivery") have one, and only the rider renting that scooter
-- can open it. Items stay in the box between rides.
return {
    Enabled = true, -- false: no target option, no stash; the box stays shut
    Inventory = 'auto', -- 'auto' detects ox_inventory, then qb-inventory; or force one of those resource names
    Slots = 10, -- stash slots
    MaxWeight = 25000, -- stash capacity in grams
    Label = 'SCOOT storage', -- inventory title
    AdminAccess = true, -- players with the admin panel's edit permission (Admin.EditAce) can open any box, rented or not
    Distance = 1.6, -- metres from the scooter the target option shows at
    TargetPadding = 0.08, -- metres added around the box for the target aim, so its edges are easy to hit
    AutoCloseDistance = 8.0, -- metres; walking further than this with the stash open closes it and the lid
    PromptKey = 38, -- E; open storage from the text prompt used when ox_target is not running
}

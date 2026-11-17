# Fuel and gas stations

Fuel lives in the existing `personal_vehicles.fuel` column in litres. New cars
receive 30 L; the default tank holds 60 L. `fuel_config.lua` configures model tank
sizes, speed bands, sample/save intervals, prices, delivery rate and 12 stock
forecourts: Idlewood, Temple, Easter Basin, Juniper Hollow, Xoomer, Spinybed,
Flint County, Dillimore, Angel Pine, Tierra Robada, El Quebrados and Bone County.
Each station uses an invisible sphere and standard gas-station blip 51.
Coordinates are stock GTA SA locations; custom maps may require adjusting zones.

The former unused fuel values are retained in `fuel_legacy` on first migration.
Existing fuel is interpreted as litres and limited to the model's tank capacity;
missing values default to 30 L. Migration does not drop tables or change vehicle
ownership, tuning, parking, or other saved attributes.

Consumption uses sampled 3D distance in metres and configurable L/100 km bands.
Idle and engine-off movement consume nothing. Large jumps, stalled samples and
interior/dimension transitions are excluded. Existing tuning teleports reset the
sample explicitly. Other scripts teleporting a tracked car should also call
`resetVehicleFuelSample(vehicle)` through the rp_car export, particularly for
small displacements indistinguishable from normal movement.

Drivers get one arrival hint and one stopped hint per visit. Press E while stopped
below 1 km/h with the engine off. Only the vehicle owner can purchase fuel.
The menu uses the shared core UI lock, a slider, full-tank selection, price and
progress. Default price is $5/L; delivery is 2 L/s. Starting the engine while
refuelling or with an empty tank is rejected by the existing engine handler.
Leaving the vehicle/zone, death, logout, quit or resource stop cancels delivery.

Payment escrow is recorded in `car_fuel_orders` in rp_core's existing SQLite
money database through its exported query API. SQLite triggers atomically debit
on insertion and refund the undelivered amount on settlement. A partial unique
index prevents two active orders for one car. Refund settlement is idempotent.
There is no new database file. The car database is a replayable projection of
journaled delivery: interrupted orders are recovered before refuelling becomes
available, their delivered quantity is restored, and the remainder refunded.
The charge for a partial litre rounds up to whole dollars; the refund is the
initial charge minus the rounded-up cost of delivered fuel.

Fuel is saved on despawn/destruction, owner quit (existing despawn path), resource
stop, completion/cancellation and periodically for changed vehicles. Delivery
progress is journaled and projected each server tick. The clients receive only
display values; client element-data changes cannot alter authoritative fuel.

The speedometer retains its design, adds litres with 15%/5% warning colours and
an engine silhouette (ENG) showing actual engine state. B and N indicators keep
their previous custom-handbrake and locked-door meanings.

Validation from repository root:

```sh
lua resources/rp_car/tests/fuel_test.lua
lua resources/rp_car/tests/fuel_ui_test.lua
lua resources/rp_car/tests/speedometer_test.lua
python3 resources/rp_car/tests/fuel_sql_test.py
```

Use Lua 5.1. Lua tests simulate MTA APIs; Python tests execute the actual escrow
DDL/triggers on SQLite. They do not replace testing in a running MTA server.
After installing this version, restart `rp_car`. In-game checks still needed:
visit stock forecourts, drive/save/respawn, refuel with two simultaneous players,
cancel by exiting, and restart during refuelling to inspect restored balances
and litres against the journal. Stop the server cleanly for routine maintenance.

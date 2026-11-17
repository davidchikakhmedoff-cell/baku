"""Run from repository root: python3 resources/rp_car/tests/fuel_sql_test.py."""
import re
import sqlite3
import unittest
from pathlib import Path

SOURCE = Path('resources/rp_car/fuel_server.lua').read_text()

class EscrowTests(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(':memory:')
        self.db.execute('CREATE TABLE players (id INTEGER PRIMARY KEY, money INTEGER)')
        self.db.execute('INSERT INTO players VALUES (1, 1000)')
        table = re.search(r'CREATE TABLE IF NOT EXISTS car_fuel_orders \(.*?\)\]\]', SOURCE, re.S)[0][:-2]
        self.db.execute(table)
        for sql in re.findall(r'\[\[(CREATE TRIGGER .*?)\]\]', SOURCE, re.S):
            self.db.execute(sql)
        self.db.execute('CREATE UNIQUE INDEX car_fuel_one_active ON car_fuel_orders(vehicle_id) WHERE settled=0')

    def buy(self, paid=50):
        self.db.execute('INSERT INTO car_fuel_orders (account_id, vehicle_id, base, requested, price, paid) VALUES (1,1,30,10,5,?)', (paid,))

    def money(self):
        return self.db.execute('SELECT money FROM players WHERE id=1').fetchone()[0]

    def test_charge_and_refund_once(self):
        self.buy()
        self.assertEqual(self.money(), 950)
        self.db.execute('UPDATE car_fuel_orders SET delivered=2, charged=10, settled=1 WHERE id=1 AND settled=0')
        self.assertEqual(self.money(), 990)
        self.db.execute('UPDATE car_fuel_orders SET settled=1 WHERE id=1')
        self.assertEqual(self.money(), 990)

    def test_insufficient_funds_atomic(self):
        with self.assertRaises(sqlite3.IntegrityError):
            self.buy(1001)
        self.assertEqual(self.money(), 1000)
        self.assertEqual(self.db.execute('SELECT COUNT(*) FROM car_fuel_orders').fetchone()[0], 0)

    def test_two_sessions_cannot_debit_twice(self):
        self.buy()
        with self.assertRaises(sqlite3.IntegrityError):
            self.buy()
        self.assertEqual(self.money(), 950)

    def test_restart_order_preserves_progress(self):
        self.buy()
        self.db.execute('UPDATE car_fuel_orders SET delivered=3.5 WHERE id=1')
        self.db.commit()
        data = self.db.serialize()
        restored = sqlite3.connect(':memory:')
        restored.deserialize(data)
        base, delivered, paid, price = restored.execute('SELECT base,delivered,paid,price FROM car_fuel_orders WHERE settled=0').fetchone()
        self.assertEqual(base + delivered, 33.5)
        self.assertEqual(paid, 50)
        self.assertEqual(price, 5)

    def test_multiple_vehicles(self):
        self.buy()
        self.db.execute('INSERT INTO car_fuel_orders (account_id, vehicle_id, base, requested, price, paid) VALUES (1,2,10,5,5,25)')
        self.assertEqual(self.money(), 925)

if __name__ == '__main__':
    unittest.main()

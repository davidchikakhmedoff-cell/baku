"""Execute the resource's actual SQLite schema/triggers, no external packages."""
from pathlib import Path
import re
import sqlite3
import unittest

SCHEMA = re.findall(r'\[\[(.*?)\]\]', Path('resources/rp_fraction/server/database.lua').read_text(), re.S)

class FractionSQLTests(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(':memory:')
        self.db.execute('CREATE TABLE players(id INTEGER PRIMARY KEY,money INTEGER NOT NULL)')
        self.db.executemany('INSERT INTO players VALUES(?,?)', [(1,1000),(2,2000)])
        for sql in SCHEMA:
            self.db.execute(sql)
    def money(self, account=1):
        return self.db.execute('SELECT money FROM players WHERE id=?',(account,)).fetchone()[0]
    def test_salary_atomic_idempotence(self):
        self.db.execute('INSERT INTO fraction_members(account_id,faction_id,rank,salary_ms) VALUES(1,2,2,3600000)')
        for _ in range(2):
            self.db.execute("INSERT OR IGNORE INTO fraction_rewards VALUES('salary:1:1',1,650,'salary')")
        self.assertEqual(self.money(),1650)
        self.assertEqual(self.db.execute('SELECT salary_ms,salary_cycle FROM fraction_members').fetchone(),(0,1))
    def test_news_claim_and_reward_once(self):
        self.db.execute("INSERT INTO fraction_ads(account_id,author,display_id,original,edited,created_at) VALUES(2,'Author',15,'original','edited',1)")
        first=self.db.execute("UPDATE fraction_ads SET status='published',editor_id=1 WHERE id=1 AND status='pending'").rowcount
        second=self.db.execute("UPDATE fraction_ads SET status='published',editor_id=2 WHERE id=1 AND status='pending'").rowcount
        self.assertEqual((first,second),(1,0))
        self.assertEqual((self.money(),self.money(2)),(1150,2000))
    def test_ticket_insufficient_funds_and_duplicate(self):
        self.db.execute("INSERT INTO fraction_tickets(account_id,officer_id,amount,reason,created_at) VALUES(1,2,1500,'reason',1)")
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute('UPDATE fraction_tickets SET paid=1 WHERE id=1')
        self.assertEqual(self.money(),1000)
        self.assertEqual(self.db.execute('SELECT paid FROM fraction_tickets').fetchone()[0],0)
        self.db.execute('UPDATE players SET money=2000 WHERE id=1')
        self.db.execute('UPDATE fraction_tickets SET paid=1 WHERE id=1 AND paid=0')
        self.db.execute('UPDATE fraction_tickets SET paid=1 WHERE id=1 AND paid=0')
        self.assertEqual(self.money(),500)
    def test_one_leader(self):
        self.db.execute('INSERT INTO fraction_members(account_id,faction_id,rank) VALUES(1,2,10)')
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute('INSERT INTO fraction_members(account_id,faction_id,rank) VALUES(2,2,10)')
        self.db.execute('INSERT INTO fraction_members(account_id,faction_id,rank) VALUES(2,4,10)')
    def test_restart_persistence(self):
        self.db.execute('INSERT INTO fraction_members(account_id,faction_id,rank,salary_ms,civilian_skin) VALUES(1,1,5,125000,7)')
        self.db.execute('INSERT INTO fraction_state(account_id,jail_remaining,wanted) VALUES(1,420,0)')
        self.db.execute("INSERT INTO fraction_vehicle_fuel VALUES('fraction:1:1',17.5)")
        self.db.commit()
        restored=sqlite3.connect(':memory:');restored.deserialize(self.db.serialize())
        for sql in SCHEMA:
            restored.execute(sql)
        self.assertEqual(restored.execute('SELECT rank,salary_ms,civilian_skin FROM fraction_members').fetchone(),(5,125000,7))
        self.assertEqual(restored.execute('SELECT jail_remaining FROM fraction_state').fetchone()[0],420)
        self.assertEqual(restored.execute('SELECT fuel FROM fraction_vehicle_fuel').fetchone()[0],17.5)

if __name__ == '__main__':
    unittest.main()

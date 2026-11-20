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
        self.assertEqual((self.money(),self.money(2)),(1080,1850))
    def test_news_insufficient_funds_rolls_back_everything(self):
        self.db.execute('UPDATE players SET money=149 WHERE id=2')
        self.db.execute("INSERT INTO fraction_ads(account_id,author,display_id,original,edited,created_at) VALUES(2,'Author',15,'original','edited',1)")
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("UPDATE fraction_ads SET status='published',editor_id=1 WHERE id=1 AND status='pending'")
        self.assertEqual((self.money(),self.money(2)),(1000,149))
        self.assertEqual(self.db.execute('SELECT status FROM fraction_ads').fetchone()[0],'pending')
        self.assertEqual(self.db.execute('SELECT COUNT(*) FROM fraction_rewards').fetchone()[0],0)

    def test_news_own_ad_requires_full_price_and_pays_net(self):
        self.db.execute("INSERT INTO fraction_ads(account_id,author,display_id,original,edited,created_at) VALUES(1,'Author',15,'text','text',1)")
        self.db.execute("UPDATE fraction_ads SET status='published',editor_id=1 WHERE id=1 AND status='pending'")
        self.assertEqual(self.money(),930)

    def test_news_submission_cooldown_survives_deletion_and_restart(self):
        sql="INSERT INTO fraction_ads(account_id,author,display_id,original,edited,created_at) VALUES(2,'Author',15,'text','text',?)"
        self.db.execute(sql,(1000,))
        self.db.execute('DELETE FROM fraction_ads')
        self.db.commit()
        restored=sqlite3.connect(':memory:');restored.deserialize(self.db.serialize())
        for statement in SCHEMA: restored.execute(statement)
        with self.assertRaises(sqlite3.IntegrityError): restored.execute(sql,(1179,))
        restored.execute(sql,(1180,))
        self.assertEqual(restored.execute('SELECT submitted_at FROM fraction_ad_cooldowns WHERE account_id=2').fetchone()[0],1180)

    def test_news_rejection_is_free(self):
        self.db.execute("INSERT INTO fraction_ads(account_id,author,display_id,original,edited,created_at) VALUES(2,'Author',15,'text','text',1)")
        self.db.execute("UPDATE fraction_ads SET status='rejected',editor_id=1 WHERE id=1")
        self.assertEqual((self.money(),self.money(2)),(1000,2000))

    def test_ticket_insufficient_funds_and_duplicate(self):
        self.db.execute("INSERT INTO fraction_tickets(account_id,officer_id,amount,reason,created_at) VALUES(1,2,1500,'reason',1)")
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute('UPDATE fraction_tickets SET paid=1 WHERE id=1')
        self.assertEqual(self.money(),1000)
        self.assertEqual(self.money(2),2000)
        self.assertEqual(self.db.execute('SELECT paid FROM fraction_tickets').fetchone()[0],0)
        self.db.execute('UPDATE players SET money=2000 WHERE id=1')
        self.db.execute('UPDATE fraction_tickets SET paid=1 WHERE id=1 AND paid=0')
        self.db.execute('UPDATE fraction_tickets SET paid=1 WHERE id=1 AND paid=0')
        self.assertEqual(self.money(),500)
        self.assertEqual(self.money(2),2900)
        self.assertEqual(self.db.execute("SELECT COUNT(*),amount FROM fraction_rewards WHERE kind='ticket'").fetchone(),(1,900))
    def test_ticket_unpaid_has_no_reward(self):
        self.db.execute("INSERT INTO fraction_tickets(account_id,officer_id,amount,reason,created_at) VALUES(1,2,100,'reason',1)")
        self.assertEqual((self.money(),self.money(2)),(1000,2000))
        self.assertEqual(self.db.execute('SELECT COUNT(*) FROM fraction_rewards').fetchone()[0],0)
    def test_ticket_self_payment(self):
        self.db.execute("INSERT INTO fraction_tickets(account_id,officer_id,amount,reason,created_at) VALUES(1,1,100,'test',1)")
        self.db.execute('UPDATE fraction_tickets SET paid=1 WHERE id=1 AND paid=0')
        self.db.execute('UPDATE fraction_tickets SET paid=1 WHERE id=1 AND paid=0')
        self.assertEqual(self.money(),960)
    def test_ticket_self_insufficient_is_atomic(self):
        self.db.execute("INSERT INTO fraction_tickets(account_id,officer_id,amount,reason,created_at) VALUES(1,1,1500,'test',1)")
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute('UPDATE fraction_tickets SET paid=1 WHERE id=1')
        self.assertEqual(self.money(),1000)
        self.assertEqual(self.db.execute('SELECT COUNT(*) FROM fraction_rewards').fetchone()[0],0)
    def test_ticket_reward_persists_for_offline_officer(self):
        self.db.execute("INSERT INTO fraction_tickets(account_id,officer_id,amount,reason,created_at) VALUES(1,2,101,'test',1)")
        self.db.execute('UPDATE fraction_tickets SET paid=1 WHERE id=1')
        self.db.commit()
        restored=sqlite3.connect(':memory:');restored.deserialize(self.db.serialize())
        self.assertEqual(restored.execute('SELECT money FROM players WHERE id=2').fetchone()[0],2060)
        for sql in SCHEMA: restored.execute(sql)
        self.assertEqual(restored.execute('SELECT money FROM players WHERE id=2').fetchone()[0],2060)
    def test_wanted_persists_until_booking(self):
        self.db.execute('INSERT INTO fraction_state(account_id,wanted,jail_remaining) VALUES(1,6,0)')
        self.db.commit()
        restored=sqlite3.connect(':memory:');restored.deserialize(self.db.serialize())
        for sql in SCHEMA: restored.execute(sql)
        self.assertEqual(restored.execute('SELECT wanted,jail_remaining FROM fraction_state').fetchone(),(6,0))
        restored.execute('UPDATE fraction_state SET wanted=0,jail_remaining=1800 WHERE account_id=1')
        restored.commit()
        restarted=sqlite3.connect(':memory:');restarted.deserialize(restored.serialize())
        self.assertEqual(restarted.execute('SELECT wanted,jail_remaining FROM fraction_state').fetchone(),(0,1800))
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

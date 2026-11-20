FractionDB={}
function FractionDB.available()
 local r=getResourceFromName('rp_core');return r and getResourceState(r)=='running'
end
function FractionDB.query(sql,...)
 if not FractionDB.available() then return {} end
 return exports.rp_core:AuthDBQuery(sql,...)
end
function FractionDB.exec(sql,...)
 if not FractionDB.available() then return false end
 return exports.rp_core:AuthDBExec(sql,...)
end
function FractionDB.one(sql,...) return FractionDB.query(sql,...)[1] end
function FractionDB.change(sql,...)
 if not FractionDB.exec(sql,...) then return false end
 local r=FractionDB.one("SELECT changes() AS n");return r and tonumber(r.n)==1
end
function FractionDB.init()
 FractionDB.exec("DROP TRIGGER IF EXISTS fraction_salary")
 FractionDB.exec("DROP TRIGGER IF EXISTS fraction_news_reward")
 FractionDB.exec("DROP TRIGGER IF EXISTS fraction_news_submission_guard")
 FractionDB.exec("DROP TRIGGER IF EXISTS fraction_news_submission")
 FractionDB.exec("DROP TRIGGER IF EXISTS fraction_ticket_payment")
 local statements={
 [[CREATE TABLE IF NOT EXISTS fraction_members(account_id INTEGER PRIMARY KEY,faction_id INTEGER NOT NULL,rank INTEGER NOT NULL,civilian_skin INTEGER NOT NULL DEFAULT 0,salary_ms INTEGER NOT NULL DEFAULT 0,salary_cycle INTEGER NOT NULL DEFAULT 0,armory_at INTEGER NOT NULL DEFAULT 0,duty INTEGER NOT NULL DEFAULT 0,civilian_weapons TEXT DEFAULT '[]')]],
 [[CREATE TABLE IF NOT EXISTS fraction_state(account_id INTEGER PRIMARY KEY,wanted INTEGER DEFAULT 0,jail_remaining INTEGER DEFAULT 0,jail_reason TEXT DEFAULT '',last_jail INTEGER DEFAULT 0)]],
 [[CREATE TABLE IF NOT EXISTS fraction_tickets(id INTEGER PRIMARY KEY AUTOINCREMENT,account_id INTEGER NOT NULL,officer_id INTEGER NOT NULL,amount INTEGER NOT NULL,reason TEXT NOT NULL,created_at INTEGER NOT NULL,paid INTEGER DEFAULT 0)]],
 [[CREATE TABLE IF NOT EXISTS fraction_ads(id INTEGER PRIMARY KEY AUTOINCREMENT,account_id INTEGER NOT NULL,author TEXT NOT NULL,display_id INTEGER NOT NULL,original TEXT NOT NULL,edited TEXT NOT NULL,created_at INTEGER NOT NULL,status TEXT DEFAULT 'pending',editor_id INTEGER,editor_name TEXT)]],
 [[CREATE TABLE IF NOT EXISTS fraction_ad_cooldowns(account_id INTEGER PRIMARY KEY,submitted_at INTEGER NOT NULL)]],
 [[INSERT OR IGNORE INTO fraction_ad_cooldowns(account_id,submitted_at) SELECT account_id,MAX(created_at) FROM fraction_ads GROUP BY account_id]],
 [[CREATE INDEX IF NOT EXISTS fraction_pending_author ON fraction_ads(account_id,status)]],
 [[CREATE TRIGGER IF NOT EXISTS fraction_news_submission_guard BEFORE INSERT ON fraction_ads BEGIN SELECT CASE WHEN COALESCE((SELECT submitted_at FROM fraction_ad_cooldowns WHERE account_id=NEW.account_id),-180)>NEW.created_at-180 THEN RAISE(ABORT,'news submission cooldown') END; END]],
 [[CREATE TRIGGER IF NOT EXISTS fraction_news_submission AFTER INSERT ON fraction_ads BEGIN INSERT OR REPLACE INTO fraction_ad_cooldowns(account_id,submitted_at) VALUES(NEW.account_id,NEW.created_at); END]],
 [[CREATE TABLE IF NOT EXISTS fraction_rewards(id TEXT PRIMARY KEY,account_id INTEGER NOT NULL,amount INTEGER NOT NULL,kind TEXT NOT NULL)]],
 [[CREATE TRIGGER IF NOT EXISTS fraction_reward AFTER INSERT ON fraction_rewards BEGIN UPDATE players SET money=money+NEW.amount WHERE id=NEW.account_id; END]],
 [[CREATE TRIGGER IF NOT EXISTS fraction_salary AFTER INSERT ON fraction_rewards WHEN NEW.kind='salary' BEGIN UPDATE fraction_members SET salary_ms=MAX(0,salary_ms-3600000),salary_cycle=salary_cycle+1 WHERE account_id=NEW.account_id; END]],
 [[CREATE UNIQUE INDEX IF NOT EXISTS fraction_one_leader ON fraction_members(faction_id) WHERE (faction_id=1 AND rank=6) OR (faction_id=2 AND rank=10) OR (faction_id=3 AND rank=5) OR (faction_id IN (4,5,6) AND rank=10)]],
 [[CREATE TABLE IF NOT EXISTS fraction_vehicle_fuel(vehicle_key TEXT PRIMARY KEY,fuel REAL NOT NULL DEFAULT 30)]],
 [[CREATE TRIGGER IF NOT EXISTS fraction_news_reward AFTER UPDATE OF status ON fraction_ads WHEN OLD.status='pending' AND NEW.status='published' BEGIN SELECT CASE WHEN COALESCE((SELECT money FROM players WHERE id=NEW.account_id),-1)<150 THEN RAISE(ABORT,'insufficient news funds') END; SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM players WHERE id=NEW.editor_id) THEN RAISE(ABORT,'news editor missing') END; UPDATE players SET money=money-150 WHERE id=NEW.account_id; INSERT OR IGNORE INTO fraction_rewards(id,account_id,amount,kind) SELECT 'news:'||NEW.id,NEW.editor_id,80,'news'; END]],
 [[CREATE TRIGGER IF NOT EXISTS fraction_ticket_payment AFTER UPDATE OF paid ON fraction_tickets WHEN OLD.paid=0 AND NEW.paid=1 BEGIN SELECT CASE WHEN COALESCE((SELECT money FROM players WHERE id=NEW.account_id),-1)<NEW.amount THEN RAISE(ABORT,'insufficient funds') END; UPDATE players SET money=money-NEW.amount WHERE id=NEW.account_id; INSERT OR IGNORE INTO fraction_rewards(id,account_id,amount,kind) VALUES('ticket:'||NEW.id,NEW.officer_id,CAST(NEW.amount * 60 / 100 AS INTEGER),'ticket'); END]]}
 for _,sql in ipairs(statements) do
  if sql:find("fraction_salary AFTER",1,true) then sql=sql:gsub("3600000",tostring(FractionConfig.salaryHourMs)) end
  if sql:find("fraction_news_reward AFTER",1,true) then
   sql=sql:gsub("<150","<"..tostring(FractionConfig.newsPrice)):gsub("money%-150","money-"..tostring(FractionConfig.newsPrice)):gsub("80,'news'",tostring(FractionConfig.newsReward)..",'news'")
  end
  if sql:find("fraction_news_submission_guard BEFORE",1,true) then sql=sql:gsub("180",tostring(FractionConfig.cooldown.add)) end
  if sql:find("fraction_ticket_payment AFTER",1,true) then sql=sql:gsub("NEW.amount %* 60 / 100", "NEW.amount * "..tostring(FractionConfig.ticket.officerPercent).." / 100") end
  assert(FractionDB.exec(sql),'fraction database migration failed')
 end
 local columns=FractionDB.query('PRAGMA table_info(fraction_members)');local hasGear=false
 for _,column in ipairs(columns) do if column.name=='gear_issued' then hasGear=true end end
 if not hasGear then FractionDB.exec('ALTER TABLE fraction_members ADD COLUMN gear_issued INTEGER NOT NULL DEFAULT 0') end
 -- Resource restart does not disconnect players: keep ads whose authors are
 -- still online, discard only genuinely offline authors' pending requests.
 local online={}
 for _,p in ipairs(getElementsByType('player')) do
  if getElementData(p,'auth:loggedIn')==true then
   local id=tonumber(exports.rp_core:getAuthPlayerId(p));if id then online[id]=true end
  end
 end
 for _,ad in ipairs(FractionDB.query("SELECT id,account_id FROM fraction_ads WHERE status='pending'")) do
  if not online[tonumber(ad.account_id)] then FractionDB.exec("DELETE FROM fraction_ads WHERE id=? AND status='pending'",ad.id) end
 end
end

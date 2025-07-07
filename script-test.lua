-- Script ที่จะเรียกใช้ระบบกาชาของเรา

local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

-- 1. ดึงโมดูลสุดเท่ของเราเข้ามา
local GachaSystem = require( เขียนที่อยู่ของโมดูล Gacha )

-- 2. ตั้งค่าตู้กาชาตามใจชอบเลย
local mythicalBladeBannerConfig = {
	Tiers = {
		["Mythic"] = {
			Abbr = "MYT", -- กำหนดชื่อย่อเอง
			Rate = "0.01%",
			Pity = 500,
			Items = {
				["ดาบพิฆาตมังกร"] = { Rate = "100%" },
			}
		},
		["Legendary"] = {
			Abbr = "LGD",
			Rate = "1%",
			Pity = 90,
			Items = {
				["ดาบแห่งแสง"] = { Rate = "50%" },
				["โล่แห่งเทพ"] = { Rate = "50%" },
			}
		},
		["Rare"] = {
			-- ไม่ใส่ Abbr เดี๋ยวระบบมันคิดให้เองเป็น "RAR"
			Rate = "15%",
			Pity = 10,
			Items = {
				["หมวกเหล็ก"] = { Rate = "40%" },
				["เกราะเหล็ก"] = { Rate = "40%" },
				["ยาเพิ่มเลือด(ใหญ่)"] = { Rate = "20%" },
			}
		},
		["Common"] = {
			Abbr = "CMN",
			IsGuaranteedTier = true, -- อันนี้คือระดับ "ขยะ" ที่จะรับเรทที่เหลือทั้งหมดไป
			Pity = 0, -- ไม่มีการันตีของกากๆ หรอกนะ
			Items = {
				["ไม้หน้าสาม"] = { Rate = "60%" },
				["ก้อนหิน"] = { Rate = "30%" },
				["ยาเพิ่มเลือด(เล็ก)"] = { Rate = "10%" },
			}
		}
	}
}

-- พอผู้เล่นเข้าเกม...
Players.PlayerAdded:Connect(function(player)

	print(string.format("ผู้เล่น %s เข้ามาแล้ว!", player.Name))

	-- สมมติว่านี่คือข้อมูล Pity ที่โหลดมาจาก DataStore
	local loadedPityData = {
		LGD = 88, -- อีก 2 ครั้งจะได้ Legendary แล้ว!
		RAR = 5,
	}

	-- 3. สร้างตู้กาชาสำหรับผู้เล่นคนนี้โดยเฉพาะ
	local playerGacha = GachaSystem.new(mythicalBladeBannerConfig)

	-- 4. โหลดข้อมูล Pity ที่เซฟไว้กลับเข้าระบบ
	playerGacha:LoadData(loadedPityData)
	print("โหลดข้อมูล Pity เก่า:", loadedPityData)

	-- 5. จำลองการสุ่ม 5 ครั้งรวด
	task.wait(3)
	print("\n>>> กดกาชา 5 ครั้งรัวๆ ไปเลยเพื่อน! <<<")
	local results = playerGacha:Roll(nil, 5) -- ไม่ใส่โบนัสโชค, สุ่ม 5 ครั้ง

	-- 6. แสดงผลลัพธ์ให้ดูหน่อย
	print("===== ผลลัพธ์ที่ได้ =====")
	for i, result in ipairs(results) do
		print(string.format("ครั้งที่ %d: ได้ของระดับ [%s] ชื่อ '%s'", i, result.Tier, result.ItemID))

		-- เช็คหน่อยว่าการันตีแตกมั้ย
		if result.Tier == "Legendary" then
			print(">>> โอ้โห! การันตีระดับ Legendary แตก! แต้มรีเซ็ตแล้วนะ <<<")
		end
	end
	print("=========================\n")


	-- 7. ดึงข้อมูล Pity ล่าสุดออกมา เพื่อเตรียมเซฟ
	local dataToSave = playerGacha:GetData()
	print("ข้อมูล Pity ล่าสุดที่จะเอาไปเซฟ (เฉพาะอันที่มีการันตี):", dataToSave)
	-- ผลลัพธ์ที่คาดหวัง: { LGD = 0, RAR = 0, MYT = 5 } (ถ้าสุ่ม 5 ครั้ง)
	-- สังเกตว่า CMN จะไม่โผล่มา เพราะเราตั้ง Pity = 0 ไว้

	-- ทดลองใช้ฟังก์ชันแปลงชื่อย่อ
	local fullName = playerGacha:GetTierFullName("RAR")
	print("FYI: ชื่อเต็มของ 'RAR' คือ '"..tostring(fullName).."'")

end)

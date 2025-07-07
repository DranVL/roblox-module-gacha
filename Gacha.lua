-- GachaSystem Module เวอร์ชั่น 1.3
-- โดย: DranVL
-- ฟีเจอร์: สุ่มกาชาแบบมีระดับ (Tier), มีการันตี (Pity),
-- แถมย่อข้อมูลให้เล็กจิ๋วตอนเซฟ

local GachaSystem = {}
GachaSystem.__index = GachaSystem

-- #######################################################
-- ##### ฟังก์ชันตัวช่วยเล็กๆ น้อยๆ ที่ใช้ภายใน #####
-- #######################################################

-- ฟังก์ชันนี้เอาไว้แปลงเรทที่เป็นข้อความ "50%" หรือตัวเลข 50 ให้กลายเป็น 0.5
-- จะได้เอาไปคำนวณง่ายๆ ไง
local function parseRate(rate: string | number): number
	if typeof(rate) == "string" then
		-- หุ้มวงเล็บไว้หน่อย กันบั๊กแปลกๆ ตอนแปลงข้อความเป็นตัวเลข
		local num = tonumber((rate:gsub("%%", "")))
		if num then
			return num / 100
		end
		warn("เฮ้เพื่อน! เรทกาชาแปลกๆ นะ รูปแบบมันเพี้ยนไป ->", rate)
		return 0
	elseif typeof(rate) == "number" then
		return rate / 100
	end
	warn("เฮ้ย! ประเภทข้อมูลเรทมันไม่ใช่ข้อความหรือตัวเลขอ่ะ ->", typeof(rate))
	return 0
end

-- ฟังก์ชันนี้คือพระเอกเลย มันจะสร้าง "{}สุ่มของ" ขึ้นมา
-- คือเอาของแต่ละชิ้นพร้อมเรทของมัน มาเรียงต่อกันเป็นแถวๆ
-- พอจะสุ่มที ก็แค่โยนลูกเต๋าลงไป ตกช่องไหนก็ได้ของชิ้นนั้นไปเลย
local function createWeightedTable(items: {[any]: {Rate: string | number}}): ({ {Item: any, Weight: number} }, number)
	local weightedTable = {}
	local totalWeight = 0

	for item, data in pairs(items) do
		local rate = parseRate(data.Rate)
		if rate > 0 then
			totalWeight += rate
			table.insert(weightedTable, {
				Item = item,
				Weight = totalWeight -- นี่คือการเอาเรทมาบวกทบๆ กันไปเรื่อยๆ
			})
		end
	end

	return weightedTable, totalWeight
end

-- พอได้{}สุ่มของมาแล้ว ฟังก์ชันนี้ก็ทำหน้าที่โยนลูกเต๋าที่ว่านั่นแหละ
-- สุ่มเลขมาค่านึง แล้วดูว่ามันไปตกอยู่ในช่วงของไอเท็มชิ้นไหน
local function pickWeightedRandom(weightedTable: { {Item: any, Weight: number} }, totalWeight: number): any
	if totalWeight <= 0 then return nil end

	-- สุ่มเลขตั้งแต่ 0 ถึงน้ำหนักรวมทั้งหมด
	local randomValue = Random.new():NextNumber(0, totalWeight)

	-- วนหาดูว่าเลขที่สุ่มได้มันน้อยกว่าน้ำหนักทบของชิ้นไหนก่อน
	for _, itemData in ipairs(weightedTable) do
		if randomValue < itemData.Weight then
			return itemData.Item -- เจอแล้ว! เอาไอดีของชิ้นนี้ไปเลย
		end
	end

	-- ถ้าหลุดมาถึงนี่แสดงว่าอาจมีอะไรแปลกๆ แต่กันเหนียวไว้ก่อน ส่งของชิ้นสุดท้ายไปละกัน
	return weightedTable[#weightedTable] and weightedTable[#weightedTable].Item or nil
end


-- #######################################################
-- ##### ตัวสร้าง Module (Constructor) #####
-- #######################################################

-- เวลาจะสร้างตู้กาชาใหม่ ก็ต้องเรียกใช้ฟังก์ชันนี้แหละ
-- ส่งตาราง config เข้ามา แล้วมันจะสร้างตู้กาชาพร้อมใช้งานให้เลย
function GachaSystem.new(config: table)
	local self = setmetatable({}, GachaSystem)

	self.config = config
	self.pityCounters = {} -- ที่นับแต้มการันตีของแต่ละระดับ

	-- สำหรับแปลงชื่อเต็มเป็นชื่อย่อ และชื่อย่อกลับเป็นชื่อเต็ม
	self.tierToAbbrMap = {} -- เช่น { Legendary = "LGD" }
	self.abbrToTierMap = {} -- เช่น { LGD = "Legendary" }

	-- เตรียมข้อมูลล่วงหน้า จะได้ไม่ต้องมาคำนวณซ้ำๆ ตอนสุ่มจริง
	self.processedTiers = {}
	local totalTierRate = 0
	local guaranteedTierName = nil

	for tierName, tierData in pairs(config.Tiers) do
		self.pityCounters[tierName] = 0

		-- สร้างตัวย่อให้แต่ละระดับ
		-- ถ้านายกำหนด "Abbr" มาใน config ก็จะใช้ค่านั้น, ถ้าไม่ ก็เอา 3 ตัวอักษรแรกไป
		local abbr = tierData.Abbr or tierName:upper():sub(1, 3)

		if self.abbrToTierMap[abbr] then
			warn(string.format(
				"ระวังนะเพื่อน! ตัวย่อ '%s' มันซ้ำกันระหว่าง '%s' กับ '%s' นะ ไปแก้ใน config ให้มันไม่ซ้ำกันหน่อยก็ดี",
				abbr, self.abbrToTierMap[abbr], tierName
				))
		end

		self.tierToAbbrMap[tierName] = abbr
		self.abbrToTierMap[abbr] = tierName

		-- สร้าง{}สุ่ม "ไอเท็ม" ของระดับนี้
		local itemWeightedTable, itemTotalWeight = createWeightedTable(tierData.Items)

		self.processedTiers[tierName] = {
			Pity = tierData.Pity or 0,
			ItemWeightedTable = itemWeightedTable,
			ItemTotalWeight = itemTotalWeight,
		}

		-- เช็คว่าระดับไหนเป็นระดับ "การันตี" (รับเรทที่เหลือทั้งหมดไป)
		if tierData.IsGuaranteedTier then
			guaranteedTierName = tierName
		else
			self.processedTiers[tierName].Rate = parseRate(tierData.Rate)
			totalTierRate += self.processedTiers[tierName].Rate
		end
	end

	-- ถ้ามีระดับการันตี ก็เอาเรทที่เหลือๆ ทั้งหมดโยนให้มันไปเลย จะได้ครบ 100% พอดี
	if guaranteedTierName and totalTierRate < 1 then
		self.processedTiers[guaranteedTierName].Rate = 1 - totalTierRate
	end

	-- สุดท้าย สร้าง{}สุ่ม "ระดับ" (Tier) ทั้งหมด
	local tierWeightedTable, tierTotalWeight = createWeightedTable(self.processedTiers)
	self.tierWeightedTable = tierWeightedTable
	self.tierTotalWeight = tierTotalWeight

	return self
end


-- #######################################################
-- ##### ฟังก์ชันสาธารณะที่เรียกใช้จากข้างนอกได้ #####
-- #######################################################

-- ตอนผู้เล่นเข้าเกม ก็ใช้ฟังก์ชันนี้โหลดแต้มการันตีที่เคยเซฟไว้กลับมา
-- มันดีพอที่จะอ่านข้อมูลได้ทั้งแบบย่อ (LGD) และแบบเต็ม (Legendary) เลยนะ
function GachaSystem:LoadData(data: {[string]: number})
	if typeof(data) ~= "table" then return end

	for key, count in pairs(data) do
		local tierName: string?

		-- ลองดูก่อนว่า key ที่ได้มาเป็น "ชื่อย่อ" รึเปล่า
		if self.abbrToTierMap[key] then
			tierName = self.abbrToTierMap[key]
			-- ถ้าไม่ใช่ ลองดูว่าเป็น "ชื่อเต็ม" มั้ย (เผื่อเป็นข้อมูลเก่า)
		elseif self.pityCounters[key] then
			tierName = key
		end

		-- ถ้าเจอ ก็ยัดค่า Pity กลับเข้าไปเลย
		if tierName then
			self.pityCounters[tierName] = count
		end
	end
end

-- ฟังก์ชันนี้เด็ดสุด! เอาไว้ดึงข้อมูลไปเซฟลง DataStore
-- มันจะคืนค่า Pity เฉพาะระดับที่มีการันตี (Pity > 0) เท่านั้น
-- แถมยังแปลงชื่อเป็นตัวย่อให้ด้วย ข้อมูลจะได้เล็กๆ น่ารักๆ
function GachaSystem:GetData(): {[string]: number}
	local abbreviatedData = {}

	for tierName, count in pairs(self.pityCounters) do
		-- ดึงค่า Pity ที่ตั้งไว้ใน config มาดู
		local pitySetting = self.processedTiers[tierName].Pity

		-- เช็คก่อนว่าระดับนี้มันมีระบบการันตีจริงๆ (Pity มากกว่า 0)
		if pitySetting and pitySetting > 0 then
			-- ถ้ามี ก็ค่อยแปลงเป็นชื่อย่อแล้วยัดใส่ตารางที่จะส่งคืน
			local abbr = self.tierToAbbrMap[tierName]
			if abbr then
				abbreviatedData[abbr] = count
			end
		end
	end

	return abbreviatedData
end

-- ฟังก์ชันพิเศษ เอาไว้ถามว่า "ไอ้ตัวย่อเนี้ย ชื่อเต็มมันคืออะไรนะ?"
function GachaSystem:GetTierFullName(abbr: string): string?
	return self.abbrToTierMap[abbr]
end

-- และแล้วก็มาถึง! ฟังก์ชันสุ่มกาชานั่นเอง!
-- ส่งค่าโบนัสโชค กับจำนวนครั้งที่จะสุ่มเข้ามาได้เลย (ถ้าไม่ส่งก็ถือว่าเป็น 0 กับ 1)
function GachaSystem:Roll(luckBonus: number?, rollCount: number?): { {Tier: string, ItemID: any} }
	luckBonus = (luckBonus or 0) / 100
	rollCount = rollCount or 1

	local results = {}

	for i = 1, rollCount do
		-- ก่อนจะสุ่ม เพิ่มแต้มการันตีให้ทุกระดับไปเลย 1 แต้ม
		for tierName in pairs(self.pityCounters) do
			self.pityCounters[tierName] += 1
		end

		local chosenTier: string? = nil

		-- 1. เช็คการันตีก่อนเลย!
		-- วนหาระดับที่แต้ม Pity ถึงแล้ว
		local highestPityTier: string? = nil
		for tierName, tierData in pairs(self.processedTiers) do
			if tierData.Pity > 0 and self.pityCounters[tierName] >= tierData.Pity then
				-- เจอปุ๊บ! ล็อคเป้าเลยว่าจะให้ของระดับนี้แหละ
				highestPityTier = tierName
				break 
			end
		end

		if highestPityTier then
			chosenTier = highestPityTier
		else
			-- 2. ถ้าไม่มีใครถึงการันตี ก็สุ่มตามปกติ
			-- โบนัสโชคจะมาทำงานตรงนี้แหละ
			local effectiveTotalWeight = self.tierTotalWeight * (1 + luckBonus)
			chosenTier = pickWeightedRandom(self.tierWeightedTable, effectiveTotalWeight)
		end

		-- 3. พอได้ระดับแล้ว ก็มาสุ่มหา "ไอเท็ม" ในระดับนั้นต่อ
		if chosenTier then
			local tierInfo = self.processedTiers[chosenTier]
			local chosenItemID = pickWeightedRandom(tierInfo.ItemWeightedTable, tierInfo.ItemTotalWeight)

			if chosenItemID then
				-- ได้ของแล้ว! ยัดผลลัพธ์ใส่ตารางไว้
				table.insert(results, { Tier = chosenTier, ItemID = chosenItemID })

				-- 4. สำคัญมาก! รีเซ็ตแต้มการันตีของระดับที่เพิ่งได้ไปให้เป็น 0
				self.pityCounters[chosenTier] = 0
			else
				warn("เฮ้ย! สุ่มได้ระดับ '"..chosenTier.."' แต่ไม่มีของให้สุ่มอ่ะ เช็คเรทไอเท็มใน config ด่วนๆ")
			end
		else
			warn("อ้าว... สุ่มไม่ได้ระดับอะไรเลย สงสัยเรทของระดับทั้งหมดรวมกันไม่ถึง 100% หรือเปล่า?")
		end
	end

	return results
end

return GachaSystem

--
-- ���������/cast ����չ
--

HM_Cast = {
	bEnable = true,			-- �Ƿ�����
}
HM.RegisterCustomData("HM_Cast")

---------------------------------------------------------------------
-- ���ر���
---------------------------------------------------------------------
local _HM_Cast = {
	szTitle = "PVE ����չ",
	bStop = false,				-- ִֹͣ�к���ĺ꣨��֡��
	tLogChannel = {},		-- ���������ͷż�¼
	tLastSelect = {},			-- ���ѡ�����Ŀ���¼��ģ�� Tab��
	tCondCache = {},			-- �����жϻ��棨alias��
	nLastSayTime = 0,		-- �ϴ�ִ�� say �ĺ�����
	nLastSelTime = 0,		-- �ϴ�ѡ��Ŀ���ʱ�䣨delay��
	nLastCastFrame = 0,	-- �ϴ�ִ�� cast ���߼�֡
	bNegative = false,		-- ��ǰ�ж�Ϊ��
	bProChannel = true,	-- �Ƿ񱣻�������Ĭ�Ͽ�����
	szCmd = "",					-- ��ǰ�ж�ָ�ԭʼ��
}

-- �򵥵Ĺ�������
_HM_Cast.Sysmsg = function(szMsg) HM.Sysmsg(szMsg, "����չ") end
_HM_Cast.Debug = function(szMsg) HM.Debug(szMsg, "����չ") end
_HM_Cast.Debug2 = function(szMsg) HM.Debug2(szMsg, "����չ") end

-- BUFF ���ͣ�����+1��
_HM_Cast.tBuffType = {
	["�⹥"] = 1,	["����"] = 3,		["��Ԫ"] = 5,	["����"] = 7,
 	["��Ѩ"] = 9,	["����"] = 11,	["��"] = 13,	["ҩʯ"] = 15,
}

---------------------------------------------------------------------
-- �򵥱�������
---------------------------------------------------------------------
_HM_Cast.tSkillAlias = {
	["С�Ṧ"] = "������ʤ|��̨���|ӭ�����",
}

_HM_Cast.tNameAlias = {
	-- ����ְҵ���ڹ��ķ�
	["�����ľ�"] = "��", ["�뾭�׵�"] = "��", ["�����"] = "��",
	-- ˮ����ԾҲ����Ծ
	["ˮ����Ծ"] = "��Ծ",
	-- �����Ƶ�����״̬������ = ENTRAP
	["����"] = "����", ["������"] = "����", ["ѣ��"] = "����",  ["����"] = "����",
	-- ؤ�� ACT λ��״̬
	["����λ��״̬"] = "λ��", ["����λ��״̬"] = "λ��",
	-- ���Ա����Ƶ�����״̬
	["վ��"] = "�ɿ�", ["��·"] = "�ɿ�", ["�ܲ�"] = "�ɿ�", ["��Ծ"] = "�ɿ�",
	["��Ӿ"] = "�ɿ�", ["ˮ������"] = "�ɿ�", ["����"] = "�ɿ�",
}

---------------------------------------------------------------------
-- ���غ���
---------------------------------------------------------------------
-- ���ֱȽ�
_HM_Cast.Compare = function(dwAct, dwExp, szOp)
	if szOp == ">" then
		return dwAct > dwExp
	elseif szOp == ">=" then
		return dwAct >= dwExp
	elseif szOp == "<=" then
		return dwAct <= dwExp
	elseif szOp == "<" then
		return dwAct < dwExp
	elseif szOp == "<>" then
		return dwAct ~= dwExp
	else
		return dwAct == dwExp
	end
end

-- ���������ָ�
_HM_Cast.SplitCondArg = function(szArg)
	local bOr, tList = false, {}
	if szArg and szArg ~= "" then
		local tPart = SplitString(szArg, "|")
		if #tPart > 1 then
			bOr = true
		else
			tPart = SplitString(szArg, "-")
		end
		for _, v in ipairs(tPart) do
			local nBegin, nEnd = string.find(v, "[<>=:]+")
			if nBegin ~= nil then
				table.insert(tList, { string.sub(v, 1, nBegin - 1), string.sub(v, nBegin, nEnd), string.sub(v, nEnd + 1) })
			else
				table.insert(tList, { v })
			end
		end
	end
	return bOr, tList
end

-- ��ȡָ�� box ��ĳ����Ʒ������
_HM_Cast.GetBoxItemNum = function(dwBox, szName, nLimit)
	local me, nNum = GetClientPlayer(), 0
	local dwSize = me.GetBoxSize(dwBox) or 0
	for dwX = 0, dwSize - 1 do
		local item = GetPlayerItem(me, dwBox, dwX)
		if item and GetItemNameByItem(item) == szName then
			local nCount = 1
			if item.nGenre == ITEM_GENRE.EQUIPMENT and item.nSub == EQUIPMENT_SUB.ARROW then --Զ������
				nCount = item.nCurrentDurability
			elseif item.bCanStack then
				nCount = item.nStackNum
			end
			nNum = nNum + nCount
			if not nLimit or nNum > nLimit then
				break
			end
		end
	end
	return nNum
end

-- ��ȡ������ĳ����Ʒ������
_HM_Cast.GetBagItemNum = function(szName, nLimit)
	local me, nNum, nLimit2 = GetClientPlayer(), 0, nil
	for dwBox = 1, 6 do
		if nLimit then
			nLimit2 = nLimit - nNum
		end
		nNum = nNum + _HM_Cast.GetBoxItemNum(dwBox, szName, nLimit2)
		if not nLimit or nNum > nLimit then
			break
		end
	end
	return nNum
end

-- ����ָ���ȡ BUFF �б�
-- szCmd��buff,mbuff,debuff,mdebuff,inbuff,minbuff,bufftime,btype,detype
_HM_Cast.GetBuffList = function(tar, szCmd)
	local tBuff, myID = {}, GetClientPlayer().dwID
	local aBuff = tar.GetBuffList() or {}
	local bMe, bDe, bIn = false, false, false
	if szCmd then
		bMe = string.find(szCmd, "m[inde]-b") ~= nil
		bDe = string.find(szCmd, "de[bt]") ~= nil
		bIn = StringFindW(szCmd, "inb") ~= nil
	end
	for _, v in ipairs(aBuff) do
		if Table_BuffIsVisible(v.dwID, v.nLevel) then
			if (not bIn or v.bCanCancel) and (not bDe or not v.bCanCancel) and (not bMe or v.dwSkillSrcID == myID) then
				local szName = Table_GetBuffName(v.dwID, v.nLevel)
				tBuff[szName] = v
				if HM_TargetMon then
					local szAlias, _ = HM_TargetMon.GetBuffExType(v.dwID, v.nLevel)
					if szAlias then
						tBuff[szAlias] = v
					end
				end
			end
		end
	end
	return tBuff
end

-- ֧��ͨ������ַ���ƥ��
_HM_Cast.WildMatch = function(arg, str)
	if StringFindW(arg, "*") then
		local pat = string.gsub(arg, "*", ".-")
		if string.sub(arg, 1, 1) ~= "*" then
			pat = "^" .. pat
		end
		if string.sub(arg, -1) ~= "*" then
			pat = pat .. "$"
		end
		return string.find(str, pat) ~= nil
	else
		return arg == str
	end
end

---------------------------------------------------------------------
-- �����жϺ�����
---------------------------------------------------------------------
_HM_Cast.tCondFunc = {}
_HM_Cast.tCondFunc = {
	------------  Local hide function ------------
	_LoadTarget = function(bTarget)
		if string.sub(_HM_Cast.szCmd, 1, 2) == "tt" then
			if not _HM_Cast.tar then
				return nil
			end
			return GetTargetHandle(_HM_Cast.tar.GetTarget())
		elseif bTarget or string.sub(_HM_Cast.szCmd, 1, 1) == "t" then
			return _HM_Cast.tar
		else
			return _HM_Cast.me
		end
	end,
	_DebugResult = function(arg, bOr)
		local szOrig = _HM_Cast.szCmd .. ":" .. table.concat(arg)
		if bOr == nil then
			_HM_Cast.Sysmsg("������Ч���ж� [" .. szOrig .. "]")
		elseif bOr == true then
			_HM_Cast.Debug2("����������ж� [" .. szOrig .. "]")
		else
			_HM_Cast.Debug2("�����㲢�����ж� [" .. szOrig .. "]")
		end
		return bOr
	end,
	-- ��ⴿ��ֵ������֧��С��)
	_CheckNumber = function(arg, op, dwAct, dwMax)
		local dwExp = tonumber(arg)
		if not dwExp then
			return _HM_Cast.tCondFunc._DebugResult({ arg })
		end
		if dwExp <= 1 and dwMax and dwMax ~= 0 then
			dwAct = dwAct / dwMax
		end
		return _HM_Cast.Compare(dwAct, dwExp, op)
	end,
	-- ����ڴ��������Ƿ��ڻ��߹�ϵ���б���֧�� |��
	_CheckStringList = function(arg, szAct, bAlias, bWild)
		local szAlias = nil
		if bAlias then
			szAlias = _HM_Cast.tNameAlias[szAct]
		end
		local tArg = SplitString(arg, "|")
		for _, v in ipairs(tArg) do
			local bOk = false
			if bWild then
				bOk = _HM_Cast.WildMatch(v, szAct)
			else
				bOk = v == szAct
			end
			if szAlias and not bOk then
				bOk = (v == szAlias) or (v == _HM_Cast.tNameAlias[szAlias])
			end
			if bOk then
				return _HM_Cast.tCondFunc._DebugResult({v, "~", szAct}, true)
			end
		end
		return false
	end,
	-- ��� buff ������ʱ�䣨�룩
	_CheckBuff = function(arg)
		local tar = nil
		if string.sub(_HM_Cast.szCmd, 1, 1) == "m" then
			tar = _HM_Cast.tar
		else
			tar = _HM_Cast.tCondFunc._LoadTarget()
		end
		if not tar or not arg or arg == "" then
			return _HM_Cast.bNegative
		end
		local tBuffList = _HM_Cast.GetBuffList(tar, _HM_Cast.szCmd)
		local bOr, tArg = _HM_Cast.SplitCondArg(arg)
		local bTime = StringFindW(_HM_Cast.szCmd, "time") ~= nil
		for _, v in ipairs(tArg) do
			local bOk, k, nExp = false, v[1], tonumber(v[3])
			local buf = tBuffList[k]
			if not nExp then		-- ֻ�Ǽ������
				bOk = buf ~= nil
			else
				local nAct = 0
				if buf ~= nil then
					if bTime then	-- ʱ��
						nAct = (buf.nEndFrame - GetLogicFrameCount()) / 16
					else						-- ����
						nAct = buf.nStackNum
					end
				end
				bOk = _HM_Cast.Compare(nAct, nExp, v[2])
			end
			if bOk == bOr then
				return _HM_Cast.tCondFunc._DebugResult(v, bOr)
			end
		end
		return not bOr
	end,
	-- ��� buff ����
	_CheckBuffType = function(arg)
		local tar = _HM_Cast.tCondFunc._LoadTarget()
		if not tar or not arg or arg == "" then
			return _HM_Cast.bNegative
		end
		local bOr, tArg = _HM_Cast.SplitCondArg(arg)
		local bDe = StringFindW(_HM_Cast.szCmd, "de") ~= nil
		-- check types
		local tCheck = {}
		for _, v in ipairs(tArg) do
			local k = v[1]
			local n = _HM_Cast.tBuffType[k]
			if not n then
				_HM_Cast.Sysmsg("������Ч�� " .. _HM_Cast.szCmd .. " [" .. k .. "]")
			else
				if bDe then
					n = n + 1
				end
				tCheck[n] = k
			end
		end
		if IsEmpty(tCheck) then
			return false
		end
		-- buff list
		local tBuffList = _HM_Cast.GetBuffList(tar, _HM_Cast.szCmd)
		for k, v in pairs(tBuffList) do
			local info = GetBuffInfo(v.dwID, v.nLevel, {})
			if tCheck[info.nDetachType] then
				if bOr then
					return _HM_Cast.tCondFunc._DebugResult({tCheck[info.nDetachType], "~", k}, bOr)
				else
					tCheck[info.nDetachType] = nil
				end
			end
		end
		if not bOr then
			for k, v in pairs(tCheck) do
				return _HM_Cast.tCondFunc._DebugResult({ v }, bOr)
			end
		end
		return not bOr
	end,
	-- ��ȡĳ��Χ�ڵĵжԻ���������
	_GetCharacterNum = function(nDis, bAlly, nMax)
		local me, n = _HM_Cast.me, 0
		nDis = nDis * 64
		for k, _ in pairs(HM.GetAllNpcID()) do
			if (bAlly and IsAlly(me.dwID, k)) or (not bAlly and IsEnemy(me.dwID, k)) then
				if GetCharacterDistance(me.dwID, k) < nDis then
					n = n + 1
					if nMax and n >= nMax then
						break
					end
				end
			end
		end
		for k, _ in pairs(HM.GetAllPlayerID()) do
			if (bAlly and IsAlly(me.dwID, k)) or (not bAlly and IsEnemy(me.dwID, k)) then
				if GetCharacterDistance(me.dwID, k) < nDis then
					n = n + 1
					if nMax and n >= nMax then
						break
					end
				end
			end
		end
		return n
	end,
	------------  Check for self ------------
	bigsword = function()
		local mnt = _HM_Cast.me.GetKungfuMount()
		return mnt and mnt.dwSkillID == 10145
	end,
	horse = function() return _HM_Cast.me.bOnHorse end,
	fight = function(arg, op)
		if not _HM_Cast.me.bFightState then
			return false
		end
		if not arg or arg == "" or not _HM_Cast.nFightBegin then
			return true
		end
		local nAct = math.floor((GetTime() - _HM_Cast.nFightBegin) / 1000)
		_HM_Cast.Debug2("��ս�� [" .. nAct .. "] ��")
		return _HM_Cast.tCondFunc._CheckNumber(arg, op, nAct)
	end,
	party = function(arg, op)
		if not _HM_Cast.me.IsInParty() then
			return false
		end
		if not arg or arg == "" then
			return true
		end
		local nAct = GetClientTeam().GetTeamSize()
		_HM_Cast.Debug2("��ǰ�������� [" .. nAct .. "] ��")
		return _HM_Cast.tCondFunc._CheckNumber(arg, op, nAct)
	end,
	otaction = function()
		return _HM_Cast.me.GetOTActionState() ~= 0
	end,
	jjc = function()
		return IsInArena()
	end,
	battle = function()
		return IsInBattleField()
	end,
	duel = function()
		return _HM_Cast.tar ~= nil and _HM_Cast.tar.dwID == _HM_Cast.dwDuelID
	end,
	qidian = function(arg, op)
		local mnt = _HM_Cast.me.GetKungfuMount()
		if not mnt then
			return false
		end
		local nAct = 0
		if mnt.dwMountType == 10 then		-- TM���ֵ
			nAct = _HM_Cast.me.nCurrentEnergy
		elseif mnt.dwMountType == 6 then	-- CJ ����
			nAct = _HM_Cast.me.nCurrentRage
		else		-- ���㣺���֡����������㽣�����
			nAct = _HM_Cast.me.nAccumulateValue
		end
		return _HM_Cast.tCondFunc._CheckNumber(arg, op, nAct)
	end,
	-- ��������ֵ�����������ж�
	sun = function(arg, op)
		local me = _HM_Cast.me
		if arg == "moon" then
			arg = me.nCurrentMoonEnergy
		end
		return _HM_Cast.tCondFunc._CheckNumber(arg, op, me.nCurrentSunEnergy, me.nMaxSunEnergy)
	end,
	moon = function(arg, op)
		local me = _HM_Cast.me
		if arg == "sun" then
			arg = me.nCurrentSunEnergy
		end
		return _HM_Cast.tCondFunc._CheckNumber(arg, op, me.nCurrentMoonEnergy, me.nMaxMoonEnergy)
	end,
	fullsun = function()
		local me = _HM_Cast.me
		return me.nSunPowerValue == 1
	end,
	fullmoon = function()
		local me = _HM_Cast.me
		return me.nMoonPowerValue == 1
	end,
	life = function(arg, op)
		local tar = _HM_Cast.tCondFunc._LoadTarget()
		if not tar then
			return false
		end
		return _HM_Cast.tCondFunc._CheckNumber(arg, op, tar.nCurrentLife, tar.nMaxLife)
	end,
	mana = function(arg, op)
		local tar = _HM_Cast.tCondFunc._LoadTarget()
		if not tar then
			return false
		end
		return _HM_Cast.tCondFunc._CheckNumber(arg, op, tar.nCurrentMana, tar.nMaxMana)
	end,
	camp = function(arg)
		local tar = _HM_Cast.tCondFunc._LoadTarget()
		if not tar or not arg or arg == "" then
			return _HM_Cast.bNegative
		end
		if not IsPlayer(tar.dwID) then
			return false
		end
		local szAct = g_tStrings.STR_CAMP_TITLE[tar.nCamp]
		if tar.nCamp == CAMP.NEUTRAL then
			szAct = "����"
		end
		return _HM_Cast.tCondFunc._CheckStringList(arg, szAct)
	end,
	speed = function(arg, op)
		local tar = _HM_Cast.tCondFunc._LoadTarget()
		if not tar then
			return false
		end
		return _HM_Cast.tCondFunc._CheckNumber(arg, op, tar.nRunSpeed, tar.nRunSpeedBase)
	end,
	puppet = function(arg)
		local szAct = nil
		if _HM_Cast.dwBatteryID then
			local npc = GetNpc(_HM_Cast.dwBatteryID)
			if npc then
				szAct = string.sub(npc.szName, -4)
			end
		end
		if szAct == nil then
			return false
		end
		if not arg or arg == "" then
			return true
		end
		return _HM_Cast.tCondFunc._CheckStringList(arg, szAct)
	end,
	pet = function(arg)
		local npc = _HM_Cast.me.GetPet()
		if not npc then
			return false
		end
		if not arg or arg == "" then
			return true
		end
		return _HM_Cast.tCondFunc._CheckStringList(arg, npc.szName)
	end,
	peta = function(arg)
		local npc, aList = _HM_Cast.me.GetPet(), {}
		if not npc or not arg or arg == "" then
			return _HM_Cast.bNegative
		end
		-- load attributes
		local aSkill = Table_GetPetSkill(npc.dwTemplateID) or {}
		for k, v in ipairs(aSkill) do
			local a = GetPetActionBarSkillAnimate(k)
			if a and a:IsVisible() then
				local n = Table_GetSkillName(v[1], v[2])
				aList[n] = true
			end
		end
		-- check attributes, - | support
		local bOr, tArg = _HM_Cast.SplitCondArg(arg)
		for _, v in ipairs(tArg) do
			local k = v[1]
			local bOk = aList[k] or false
			if bOk == bOr then
				return _HM_Cast.tCondFunc._DebugResult(v, bOr)
			end
		end
		return not bOr
	end,
	map = function(arg)
		if not arg or arg == "" then
			return _HM_Cast.bNegative
		end
		local scene = _HM_Cast.me.GetScene()
		local szAct = Table_GetMapName(scene.dwMapID)
		return _HM_Cast.tCondFunc._CheckStringList(arg, szAct)
	end,
	force = function(arg)
		local tar = _HM_Cast.tCondFunc._LoadTarget()
		if not tar or not arg or arg == "" then
			return _HM_Cast.bNegative
		end
		if not IsPlayer(tar.dwID) then
			return false
		end
		local szAct = GetForceTitle(tar.dwForceID)
		return _HM_Cast.tCondFunc._CheckStringList(arg, szAct)
	end,
	mount = function(arg)
		local tar = _HM_Cast.tCondFunc._LoadTarget()
		if not tar or not arg or arg == "" then
			return _HM_Cast.bNegative
		end
		if not IsPlayer(tar.dwID) then
			return false
		end
		local mnt = tar.GetKungfuMount()
		if mnt then
			local szAct = mnt.szSkillName
			return _HM_Cast.tCondFunc._CheckStringList(arg, szAct, true)
		end
		return false
	end,
	name = function(arg)
		local tar = _HM_Cast.tCondFunc._LoadTarget()
		if not tar or not arg or arg == "" then
			return _HM_Cast.bNegative
		end
		local szAct = tar.szName
		return _HM_Cast.tCondFunc._CheckStringList(arg, szAct, false, true)
	end,
	guild = function(arg)
		local tar = _HM_Cast.tCondFunc._LoadTarget()
		if not tar or not arg or arg == "" then
			return _HM_Cast.bNegative
		end
		if tar.dwTongID and tar.dwTongID ~= 0 then
			local szAct =GetTongClient().ApplyGetTongName(tar.dwTongID)
			return _HM_Cast.tCondFunc._CheckStringList(arg, szAct, false, true)
		end
		return false
	end,
	status = function(arg)
		local tar = _HM_Cast.tCondFunc._LoadTarget()
		if not tar or not arg or arg == "" then
			return _HM_Cast.bNegative
		end
		local szAct = g_tStrings.tPlayerMoveState[tar.nMoveState]
		if tar.nMoveState == MOVE_STATE.ON_ENTRAP then
			szAct = "����"
		end
		return _HM_Cast.tCondFunc._CheckStringList(arg, szAct, true)
	end,
	cd = function(arg)
		if not arg or arg == "" then
			return _HM_Cast.bNegative
		end
		local bOr, tArg = _HM_Cast.SplitCondArg(arg)
		local bTime = StringFindW(_HM_Cast.szCmd, "time") ~= nil
		local bPass = not bOr
		for _, v in ipairs(tArg) do
			local bOk, k, nExp = false, v[1], tonumber(v[3])
			local skill = _HM_Cast.tSkill[k] or _HM_Cast.GetItem(k)
			if not skill or type(skill) == "function" then
				bPass = _HM_Cast.tCondFunc._DebugResult(v)
			else
				local nLeft, nTotal = 0, 0
				if skill.dwSkillID then
					_, nLeft, nTotal = _HM_Cast.me.GetSkillCDProgress(skill.dwSkillID, skill.dwLevel)
				else
					_, nLeft, nTotal = _HM_Cast. me.GetItemCDProgress(skill[1], skill[2])
				end
				if bTime then	-- ��� TIME
					if nExp < 1 and nExp > 0 then
						nLeft = nLeft / nTotal
					else
						nLeft = nLeft / 16
					end
					bOk = _HM_Cast.Compare(nLeft, nExp, v[2])
				else
					bOk = nLeft > 0
				end
				if bOk == bOr then
					return _HM_Cast.tCondFunc._DebugResult(v, bOr)
				end
			end
		end
		return bPass
	end,
	enemy = function(arg, op)
		local nDis = tonumber(string.sub(_HM_Cast.szCmd, 6)) or 6
		local nExp = tonumber(arg) or 1
		local nAct = _HM_Cast.tCondFunc._GetCharacterNum(nDis, false, nExp + 1)
		_HM_Cast.Debug2(nDis .. "�߷�Χ�ڵж����� [" ..  nAct .. "]")
		return _HM_Cast.Compare(nAct, nExp, op)
	end,
	ally = function(arg, op)
		local nDis = tonumber(string.sub(_HM_Cast.szCmd, 5)) or 6
		local nExp = tonumber(arg) or 1
		local nAct = _HM_Cast.tCondFunc._GetCharacterNum(nDis, true, nExp + 1)
		_HM_Cast.Debug2(nDis .. "�߷�Χ���������� [" ..  nAct .. "]")
		return _HM_Cast.Compare(nAct, nExp, op)
	end,
	bagleft = function(arg, op)
		local nAct, me = 0, _HM_Cast.me
		for dwBox = 1, BigBagPanel_nCount do
			local dwSize = me.GetBoxSize(dwBox)
			if dwSize and dwSize ~= 0 then
				nAct = nAct + me.GetBoxFreeRoomSize(dwBox)
			end
		end
		_HM_Cast.Debug2("������λ�� [" .. nAct .. "]")
		if not arg then
			return nAct > 0
		end
		return _HM_Cast.tCondFunc._CheckNumber(arg, op, nAct)
	end,
	bagitem = function(arg, op)
		if not arg or arg == "" then
			return _HM_Cast.bNegative
		end
		local bOr, tArg = _HM_Cast.SplitCondArg(arg)
		for _, v in ipairs(tArg) do
			local bOk, k, nExp = false, v[1], tonumber(v[3])
			local nAct = _HM_Cast.GetBagItemNum(k, nExp)
			if not nExp then
				bOk = nAct > 0
			else
				bOk = _HM_Cast.Compare(nAct, nExp, v[2])
			end
			if bOk == bOr then
				return _HM_Cast.tCondFunc._DebugResult(v, bOr)
			end
		end
		return not bOr
	end,
	bullet = function(arg, op)
		if not arg or arg == "" then
			return _HM_Cast.bNegative
		end
		local bOr, tArg = _HM_Cast.SplitCondArg(arg)
		for _, v in ipairs(tArg) do
			local bOk, k, nExp = false, v[1], tonumber(v[3])
			local nAct = _HM_Cast.GetBoxItemNum(INVENTORY_INDEX.BULLET_PACKAGE, k, nExp or 1)
			if not nExp then
				bOk = nAct > 0
			else
				bOk = _HM_Cast.Compare(nAct, nExp, v[2])
			end
			if bOk == bOr then
				return _HM_Cast.tCondFunc._DebugResult(v, bOr)
			end
		end
		return not bOr
	end,
	------------  Check for target------------
	dead = function()
		return _HM_Cast.tar and IsPlayer(_HM_Cast.tar.dwID) and _HM_Cast.tar.nMoveState == MOVE_STATE.ON_DEATH
	end,
	target = function(arg)
		local me, tar = _HM_Cast.me, _HM_Cast.tCondFunc._LoadTarget()
		local bOr, tArg = _HM_Cast.SplitCondArg(arg)
		local bPass = not bOr
		for _, v in ipairs(tArg) do
			local bOk = true
			if not tar then
				bOk = v[1] == "none"
			elseif v[1] == "none" then
				bOk = not tar
			elseif v[1] == "self" then
				bOk = tar.dwID == me.dwID
			elseif v[1] == "player" then
				bOk = IsPlayer(tar.dwID)
			elseif v[1] == "party" then
				bOk = me.IsPlayerInMyParty(tar.dwID)
			elseif v[1] == "npc" then
				bOk = not IsPlayer(tar.dwID)
			elseif v[1] == "boss" then
				bOk = not IsPlayer(tar.dwID) and GetNpcIntensity(tar) == 4
			elseif v[1] == "enemy" then
				bOk = IsEnemy(me.dwID, tar.dwID)
			elseif v[1] == "ally" then
				bOk = IsAlly(me.dwID, tar.dwID)
			elseif v[1] == "neutrality" then
				bOk = IsNeutrality(me.dwID, tar.dwID)
			else
				bOk = not bOr
				bPass = _HM_Cast.tCondFunc._DebugResult(v)
			end
			if bOk == bOr then
				return _HM_Cast.tCondFunc._DebugResult(v, bOr)
			end
		end
		return bPass
	end,
	angle = function(arg, op)
		local me, tar = _HM_Cast.me, _HM_Cast.tCondFunc._LoadTarget(true)
		if not tar or not arg or arg == "" then
			return _HM_Cast.bNegative
		end
		local nX = tar.nX - me.nX
		local nY = tar.nY - me.nY
		local nFace =  me.nFaceDirection / 256 * 360
		local nDeg = 0
		if nY == 0 then
			if nX < 0 then
				nDeg = 180
			end
		elseif nX == 0 then
			if nY > 0 then
				nDeg = 90
			else
				nDeg = 270
			end
		else
			nDeg = math.deg(math.atan(nY / nX))
			if nX < 0 then
				nDeg = 180 + nDeg
			elseif nY < 0 then
				nDeg = 360 + nDeg
			end
		end
		local nAngle = nFace - nDeg
		if nAngle < -180 then
			nAngle = nAngle + 360
		elseif nAngle > 180 then
			nAngle = nAngle - 360
		end
		_HM_Cast.Debug2("��Ŀ��н� [" ..  nAngle .. "]")
		if _HM_Cast.szCmd == "rangle" then
			nAngle = math.abs(nAngle)
		end
		return _HM_Cast.tCondFunc._CheckNumber(arg, op, nAngle)
	end,
	distance = function(arg, op)
		local tar = _HM_Cast.tCondFunc._LoadTarget(true)
		if not tar then
			return _HM_Cast.bNegative
		end
		local nAct = GetCharacterDistance(_HM_Cast.me.dwID, tar.dwID) / 64
		return _HM_Cast.tCondFunc._CheckNumber(arg, op, nAct)
	end,
	pdistance = function(arg, op)
		local me, npc = _HM_Cast.me, nil
		if _HM_Cast.dwBatteryID then
			npc = GetNpc(_HM_Cast.dwBatteryID)
		else
			npc = me.GetPet()
		end
		if not npc then
			return _HM_Cast.bNegative
		end
		local nAct = GetCharacterDistance(me.dwID, npc.dwID) / 64
		return _HM_Cast.tCondFunc._CheckNumber(arg, op, nAct)
	end,
	ptdistance = function(arg, op)
		local tar, me = _HM_Cast.tar, _HM_Cast.me
		if _HM_Cast.dwBatteryID then
			npc = GetNpc(_HM_Cast.dwBatteryID)
		else
			npc = me.GetPet()
		end
		if not tar or not npc then
			return _HM_Cast.bNegative
		end
		local nAct = GetCharacterDistance(tar.dwID, npc.dwID) / 64
		return _HM_Cast.tCondFunc._CheckNumber(arg, op, nAct)
	end,
	ttdistance = function(arg, op)
		local tar = _HM_Cast.tar
		if not tar then
			return false
		end
		local ttar = GetTargetHandle(tar.GetTarget())
		if not ttar then
			return false
		end
		local nAct = GetCharacterDistance(tar.dwID, ttar.dwID) / 64
		return _HM_Cast.tCondFunc._CheckNumber(arg, op, nAct)
	end,
	title = function(arg)
		local tar = _HM_Cast.tCondFunc._LoadTarget(true)
		if not tar or not arg or arg == "" then
			return _HM_Cast.bNegative
		end
		local szAct = tar.szTitle or ""
		return _HM_Cast.tCondFunc._CheckStringList(arg, szAct, false, true)
	end,
	prepare = function(arg, op)
		local tar, me = nil, _HM_Cast.me
		if string.sub(_HM_Cast.szCmd, 1, 1) == "m" then
			tar = _HM_Cast.me
		else
			tar = _HM_Cast.tCondFunc._LoadTarget(true)
		end
		if not tar then
			return _HM_Cast.bNegative
		end
		local bBroken = StringFindW(_HM_Cast.szCmd, "broken") ~= nil
		local bChannel = StringFindW(_HM_Cast.szCmd, "channel") ~= nil
		local szType = "����"
		local _dwType, _dwID = me.GetTarget()
		if _dwID ~= tar.dwID and me.dwID ~= tar.dwID and not bChannel then
			HM.SetTarget(tar.dwID)
		end
		local _, dwSkillID, dwLevel, fP = tar.GetSkillPrepareState()
		if _dwID ~= tar.dwID and me.dwID ~= tar.dwID and not bChannel then
			SetTarget(_dwType, _dwID)
		end
		if bChannel or (bBroken and (not dwSkillID or dwSkillID == 0)) then
			if _HM_Cast.tLogChannel[tar.dwID] and tar.GetOTActionState() == 2 then
				local data = _HM_Cast.tLogChannel[tar.dwID]
				dwSkillID, dwLevel = data[1], data[2]
				fP = (GetLogicFrameCount() - data[3]) / data[4]
				szType, bChannel = "����", true
			else
				dwSkillID = 0
			end
		end
		if dwSkillID == 0 then
			return false
		else
			local skill = GetSkill(dwSkillID, dwLevel)
			if not skill then
				return false
			end
			local szName = HM.GetSkillName(dwSkillID, dwLevel)
			if bBroken and not HM.CanBrokenSkill(dwSkillID) then
				_HM_Cast.Debug2("[" .. tar.szName .. "] ��" .. szType .. "���� [" .. szName .. "] ���ɴ��")
				return false
			end
			_HM_Cast.Debug2("[" .. tar.szName .. "] �����ͷ�" .. szType .. "���� [" .. szName .. "]")
			if not arg or arg == "" then
				return true
			end
			-- simplet check percentage
			if op ~= ":" then
				local dwExp = tonumber(arg) or 0
				if dwExp then
					return _HM_Cast.Compare(fP, dwExp, op)
				end
				return _HM_Cast.tCondFunc._DebugResult({ op, arg })
			end
			-- split args
			local _, tArg = _HM_Cast.SplitCondArg(string.gsub(arg, "-", "|"))
			for _, v in ipairs(tArg) do
				if szName == v[1] then
					local dwExp = tonumber(v[3])
					if not dwExp or _HM_Cast.Compare(fP, dwExp, v[2]) then
						return _HM_Cast.tCondFunc._DebugResult(v, true)
					end
				end
			end
		end
		return false
	end,
}

-- �ж�������չ������
_HM_Cast.tCondFunc["cdtime"] = _HM_Cast.tCondFunc.cd
_HM_Cast.tCondFunc["buff"] = _HM_Cast.tCondFunc._CheckBuff
_HM_Cast.tCondFunc["debuff"] = _HM_Cast.tCondFunc._CheckBuff
_HM_Cast.tCondFunc["inbuff"] = _HM_Cast.tCondFunc._CheckBuff
_HM_Cast.tCondFunc["bufftime"] = _HM_Cast.tCondFunc._CheckBuff
_HM_Cast.tCondFunc["debufftime"] = _HM_Cast.tCondFunc._CheckBuff
_HM_Cast.tCondFunc["inbufftime"] = _HM_Cast.tCondFunc._CheckBuff
_HM_Cast.tCondFunc["btype"] = _HM_Cast.tCondFunc._CheckBuffType
_HM_Cast.tCondFunc["detype"] = _HM_Cast.tCondFunc._CheckBuffType
_HM_Cast.tCondFunc["mprepare"] = _HM_Cast.tCondFunc.prepare
_HM_Cast.tCondFunc["mchannel"] = _HM_Cast.tCondFunc.prepare
_HM_Cast.tCondFunc["mbroken"] = _HM_Cast.tCondFunc.prepare
---------------------------------------------------------------------------------
_HM_Cast.tCondFunc["rangle"] = _HM_Cast.tCondFunc.angle
_HM_Cast.tCondFunc["channel"] = _HM_Cast.tCondFunc.prepare
_HM_Cast.tCondFunc["broken"] = _HM_Cast.tCondFunc.prepare
_HM_Cast.tCondFunc["tlife"] = _HM_Cast.tCondFunc.life
_HM_Cast.tCondFunc["tmana"] = _HM_Cast.tCondFunc.mana
_HM_Cast.tCondFunc["tcamp"] = _HM_Cast.tCondFunc.camp
_HM_Cast.tCondFunc["tspeed"] = _HM_Cast.tCondFunc.speed
_HM_Cast.tCondFunc["tforce"] = _HM_Cast.tCondFunc.force
_HM_Cast.tCondFunc["tmount"] = _HM_Cast.tCondFunc.mount
_HM_Cast.tCondFunc["tname"] = _HM_Cast.tCondFunc.name
_HM_Cast.tCondFunc["tguild"] = _HM_Cast.tCondFunc.guild
_HM_Cast.tCondFunc["tstatus"] = _HM_Cast.tCondFunc.status
_HM_Cast.tCondFunc["tbuff"] = _HM_Cast.tCondFunc._CheckBuff
_HM_Cast.tCondFunc["tdebuff"] = _HM_Cast.tCondFunc._CheckBuff
_HM_Cast.tCondFunc["tinbuff"] = _HM_Cast.tCondFunc._CheckBuff
_HM_Cast.tCondFunc["tbufftime"] = _HM_Cast.tCondFunc._CheckBuff
_HM_Cast.tCondFunc["tdebufftime"] = _HM_Cast.tCondFunc._CheckBuff
_HM_Cast.tCondFunc["tinbufftime"] = _HM_Cast.tCondFunc._CheckBuff
_HM_Cast.tCondFunc["tbtype"] = _HM_Cast.tCondFunc._CheckBuffType
_HM_Cast.tCondFunc["tdetype"] = _HM_Cast.tCondFunc._CheckBuffType
_HM_Cast.tCondFunc["mbuff"] = _HM_Cast.tCondFunc._CheckBuff
_HM_Cast.tCondFunc["mdebuff"] = _HM_Cast.tCondFunc._CheckBuff
_HM_Cast.tCondFunc["minbuff"] = _HM_Cast.tCondFunc._CheckBuff
_HM_Cast.tCondFunc["mbufftime"] = _HM_Cast.tCondFunc._CheckBuff
_HM_Cast.tCondFunc["mdebufftime"] = _HM_Cast.tCondFunc._CheckBuff
_HM_Cast.tCondFunc["minbufftime"] = _HM_Cast.tCondFunc._CheckBuff
--------------------------------------------------------------------------------
_HM_Cast.tCondFunc["ttarget"] = _HM_Cast.tCondFunc.target
_HM_Cast.tCondFunc["ttprepare"] = _HM_Cast.tCondFunc.prepare
_HM_Cast.tCondFunc["ttchannel"] = _HM_Cast.tCondFunc.prepare
_HM_Cast.tCondFunc["ttbroken"] = _HM_Cast.tCondFunc.prepare
_HM_Cast.tCondFunc["ttforce"] = _HM_Cast.tCondFunc.force
_HM_Cast.tCondFunc["ttname"] = _HM_Cast.tCondFunc.name
_HM_Cast.tCondFunc["ttlife"] = _HM_Cast.tCondFunc.life
_HM_Cast.tCondFunc["ttitle"] = _HM_Cast.tCondFunc.title
_HM_Cast.tCondFunc["ttbtype"] = _HM_Cast.tCondFunc._CheckBuffType
_HM_Cast.tCondFunc["ttdetype"] = _HM_Cast.tCondFunc._CheckBuffType
_HM_Cast.tCondFunc["ttbuff"] = _HM_Cast.tCondFunc._CheckBuff
_HM_Cast.tCondFunc["ttinbuff"] = _HM_Cast.tCondFunc._CheckBuff
_HM_Cast.tCondFunc["ttdebuff"] = _HM_Cast.tCondFunc._CheckBuff
_HM_Cast.tCondFunc["ttbufftime"] = _HM_Cast.tCondFunc._CheckBuff
_HM_Cast.tCondFunc["ttdebufftime"] = _HM_Cast.tCondFunc._CheckBuff
_HM_Cast.tCondFunc["ttinbufftime"] = _HM_Cast.tCondFunc._CheckBuff

-- ���������ж��еĲ������ã������жϣ�������ȡֵ��
_HM_Cast.tCondArg = {
	["delay"] = true,		-- ����ʱ������ѡĿ��� CoolTime
	["mindis"] = true,	["maxdis"] = true,
	["minhp"] = true,	["maxhp"] = true,
	["pindao"] = true,	["teamsize"] = true,	["to"] = true,
}

---------------------------------------------------------------------
-- �����ж϶���
---------------------------------------------------------------------
_HM_Cast.CondBase = class()

-- ���캯�� cmd = string|table
function _HM_Cast.CondBase:ctor(cmd, op, arg)
	if type(cmd) == "string" then
		self.nType = 1
		self.szCmd, self.szOp, self.szArg = cmd, op, arg
	else
		self.nType = 2
		self.bOr, self.tChild = false, {}
		if type(cmd) == "table" then
			self.nType = 3
			table.insert(self.tChild, cmd)
		end
	end
end

-- �������Ʒ����׸�ƥ�����������
function _HM_Cast.CondBase:Find(cmd)
	if self.nType == 1 then
		if cmd == self.szCmd then
			return self
		end
	elseif #self.tChild > 0 then
		for _, v in ipairs(self.tChild) do
			local r = v:Find(cmd)
			if r then
				return r
			end
		end
	end
end

-- �������Ʒ�����ֵ�������߼���ϵ
function _HM_Cast.CondBase:GetArg(cmd)
	if self.nType == 1 then
		if cmd == self.szCmd then
			if self.szArg then
				return HM.Trim(self.szArg)
			end
		end
	elseif #self.tChild > 0 then
		for _, v in ipairs(self.tChild) do
			local r = v:GetArg(cmd)
			if r then
				return r
			end
		end
	end
end

-- ִ��������⣬���ؽ�� true|false
function _HM_Cast.CondBase:Check()
	if self.nType == 1 then
		local szCmd = self.szCmd
		_HM_Cast.bNegative = false
		-- �񶨼�飨̾�����д���no ϵ�е����ܵ���������ϵ��
		if not _HM_Cast.tCondFunc[szCmd] then
			if szCmd:sub(1, 1) == "!" then
				_HM_Cast.bNegative = true
				szCmd = szCmd:sub(2)
			elseif _HM_Cast.tCondCache[szCmd] == nil then
				if szCmd:sub(1, 2) == "no" then
					szCmd = szCmd:sub(3)
				elseif szCmd:sub(1, 3) == "tno" then
					szCmd = "t" .. szCmd:sub(4)
				elseif szCmd:sub(1, 4) == "ttno" then
					szCmd = "tt" .. szCmd:sub(5)
				end
				if self.szCmd ~= szCmd then
					_HM_Cast.bNegative = true
					if self.szArg then
						self.szArg = string.gsub(self.szArg, "-", "|")
					end
				end
			end
		end
		-- ������
		local bPass = _HM_Cast.tCondCache[szCmd]
		if bPass ~= nil then
			if _HM_Cast.bNegative then
				return not bPass
			end
			return bPass
		end
		-- ִ�м��
		_HM_Cast.szCmd = szCmd
		if szCmd:sub(1, 5) == "enemy" then
			szCmd = "enemy"
		elseif szCmd:sub(1, 4) == "ally" then
			szCmd = "ally"
		end
		local func = _HM_Cast.tCondFunc[szCmd]
		if not func then
			if _HM_Cast.tCondArg[szCmd] then
				return nil
			end
			return _HM_Cast.Sysmsg("������Ч�ж� [" .. self.szCmd .. "]")
		else
			bPass = func(self.szArg, self.szOp)
			if _HM_Cast.bNegative and bPass ~= nil then
				bPass = not bPass
			end
			return bPass
		end
	elseif #self.tChild == 0 then
		return true
	else
		for _, v in ipairs(self.tChild) do
			local bOk = v:Check()
			if bOk == nil then	-- ���� nil ��ʾ����
				bOk = not self.bOr
			end
			if (bOk and self.bOr) or (not bOk and not self.bOr) then
				if v.nType == 1 then
					local szRaw = v.szCmd
					if v.szArg and v.szOp then
						szRaw = szRaw .. v.szOp .. v.szArg
					end
					if self.bOr == true then
						_HM_Cast.Debug2("���� [����] �ж� [" .. szRaw .. "]")
					else
						_HM_Cast.Debug2("������ [����] �ж� [" .. szRaw .. "]")
					end
				end
				return bOk
			end
		end
		return not self.bOr
	end
end

-- �������������Ϊ�������󣬼��ܣ�����
_HM_Cast.ParseInput = function(szInput)
	local nLen, tStack = szInput:len(), {}
	local tCond, szSkill, szArg, x, y, z
	for i = 1, nLen do
		local c, n = szInput:sub(i, i), #tStack
		if c == "[" then
			if n == 0 and x ~= nil then
				i = i + 1
				szSkill = szSkill or szInput:sub(x, i - 2)
				for j = nLen, i, -1 do
					if szInput:sub(j, j) == "]" then
						szArg = szInput:sub(i, j - 1)
						break
					end
				end
				break
			end
			local con = _HM_Cast.CondBase.new()
			if n > 0 then
				table.insert(tStack[n].tChild, con)
			end
			table.insert(tStack, con)
			x = nil
		elseif (c == "," or c == ";" or c == "]") and n > 0 then
			if x then
				local cmd, op, arg
				if not y then
					cmd = szInput:sub(x, i - 1)
				else
					cmd = szInput:sub(x, y - 1)
					op = szInput:sub(y, z)
					arg = szInput:sub(z + 1, i - 1)
					y = nil
				end
				local con = _HM_Cast.CondBase.new(cmd, op, arg)
				table.insert(tStack[n].tChild, con)
			end
			local m = #tStack[n].tChild
			if c == "]" then
				if tStack[n].nType == 3 then
					table.remove(tStack)
					n = n - 1
				end
				if n == 1 then
					tCond = tStack[n]
				end
				table.remove(tStack)
			elseif m < 2 then
				tStack[n].bOr = c == ";"
			elseif (c == ";" and not tStack[n].bOr) or (c == "," and tStack[n].bOr) then
				if tStack[n].nType == 3 then
					table.remove(tStack)
				else
					local con = _HM_Cast.CondBase.new(tStack[n].tChild[m])
					con.bOr = c == ";"
					tStack[n].tChild[m] = con
					table.insert(tStack, con)
				end
			end
			x = nil
		elseif (c == "=" or c == "<" or c == ">" or c == ":") and n > 0 and x ~= nil then
			if not y then
				y, z = i, i
			elseif i == (z + 1) then
				z = i
			end
		elseif c == " " then
			if x and n == 0 and not szSkill then
				szSkill = szInput:sub(x, i - 1)
				x = i + 1
			end
		else
			if not x then
				x = i
			end
			if i == nLen then
				if not szSkill then
					szSkill = szInput:sub(x, i)
				else
					szArg = HM.Trim(szInput:sub(x, i))
				end
			end
		end
	end
	return tCond, szSkill, szArg
end

-- ������Ĳ�����������������
_HM_Cast.ParseArg = function(szArg)
	local tCond = _HM_Cast.ParseInput("[" .. (szArg or "") .. "]")
	return tCond
end

---------------------------------------------------------------------
-- �鿴Ŀ�����
---------------------------------------------------------------------
-- �����ѡĿ�꣨KNpc/KPlayer��
_HM_Cast.GetFindList = function(cond)
	local me, szType, tList = GetClientPlayer(), "", {}
	if cond then
		szType = cond:GetArg("target")
	end
	if szType == "self" then
		table.insert(tList, me)
	elseif szType == "npc" or szType == "boss" then
		tList = HM.GetAllNpc()
	elseif szType == "player" or szType == "party" then
		tList = HM.GetAllPlayer()
	else
		tList = HM.GetAllPlayer()
		for _, v in ipairs(HM.GetAllNpc()) do
			table.insert(tList, v)
		end
	end
	return tList
end

-- ��������ѡһ��Ŀ�꣨���ò�����delay, maxdis, mindis, maxhp, minhp��
_HM_Cast.FindTarget = function(cond)
	local aList, _tar = _HM_Cast.GetFindList(cond), _HM_Cast.tar
	local nSort, nDelay, nSortVal, dwType, dwID, szName
	if cond then
		nDelay = cond:GetArg("delay")
		if nDelay then
			nDelay = tonumber(nDelay) or 1
			nDelay = math.ceil(nDelay * 1000)
			if (GetTime() - _HM_Cast.nLastSelTime) > nDelay then
				_HM_Cast.tLastSelect = {}
			end
		end
		if cond:Find("minhp") then
			nSort = 1
		elseif cond:Find("maxhp") then
			nSort = 2
		elseif cond:Find("mindis") then
			nSort = 3
		elseif cond:Find("maxdis") then
			nSort = 4
		end
	end
	-- traverse the target list
	for _, v in ipairs(aList) do
		local _dwType = TARGET.PLAYER
		if not IsPlayer(v.dwID) then
			_dwType = TARGET.NPC
		end
		_HM_Cast.tar = v
		_HM_Cast.Debug2("����ѡĿ�� [" .. v.szName .. "] ...")
		if (_dwType == TARGET.PLAYER or v.IsSelectable())
			and (not nDelay or not _HM_Cast.tLastSelect[v.dwID])
			and (not cond or cond:Check())
		then
			if nSort == 1 or nSort == 2 then
				local nHP = v.nCurrentLife / v.nMaxLife
				if not nSortVal
					or (nSort == 1 and nHP < nSortVal)
					or (nSort == 2 and nHP > nSortVal)
				then
					nSortVal = nHP
					dwType, dwID, szName = _dwType, v.dwID, v.szName
					_HM_Cast.Debug2("�滻ƥ��Ŀ�� [" .. szName .. "]��Ѫ�� [" .. string.format("%.2f", nHP) .. "]")
				end
			elseif nSort == 3 or nSort == 4 then
				local nDis = GetCharacterDistance(_HM_Cast.me.dwID, v.dwID)
				if not nSortVal
					or (nSort == 3 and nDis < nSortVal)
					or (nSort == 4 and nDis > nSortVal)
				then
					nSortVal = nDis
					dwType, dwID, szName = _dwType, v.dwID, v.szName
					_HM_Cast.Debug2("�滻ƥ��Ŀ�� [" .. szName .. "]������ [" .. string.format("%.1f", nSortVal / 64) .. " ��]")
				end
			else
				dwType, dwID, szName = _dwType, v.dwID, v.szName
				break
			end
		end
	end
	-- ���ز��ҽ��
	_HM_Cast.tar = _tar
	if dwID then
		if nDelay then
			_HM_Cast.nLastSelTime = GetTime()
			_HM_Cast.tLastSelect[dwID] = true
		end
		_HM_Cast.Debug("���ƥ��Ŀ�� [" .. szName .. "#" .. dwID .. "]")
	end
	return dwType, dwID
end

-- ����Ŀ�ִ꣬�лص�
_HM_Cast.WalkTarget = function(arg, cond, func)
	local aList, _tar = _HM_Cast.GetFindList(cond), _HM_Cast.tar
	local nLimit = 25
	for _, v in ipairs(aList) do
		_HM_Cast.tar = v
		_HM_Cast.Debug2("����ѡĿ�� [" .. v.szName .. "] ...")
		if (IsPlayer(v.dwID) or v.IsSelectable()) and (not cond or cond:Check()) then
			_HM_Cast.Debug2("��ƥ��Ŀ�� [" .. v.szName .. "] ִ�� [#" .. tostring(func) .. "]")
			func(arg, v.dwID, cond)
			if nLimit == 1 then
				break
			else
				nLimit = nLimit - 1
			end
		end
	end
	_HM_Cast.tar = _tar
end

---------------------------------------------------------------------
-- ��չ������ʵ��
---------------------------------------------------------------------
-- ����������Ʒ�����ڰ�ȫ��ֻ֧�֣��ң��ף��̣�
_HM_Cast.DropBagItem = function(szName)
	local me = GetClientPlayer()
	for dwBox = 1, BigBagPanel_nCount do
		local dwSize = me.GetBoxSize(dwBox) or 0
		for dwX = 0, dwSize - 1 do
			local item = GetPlayerItem(me, dwBox, dwX)
			if item and GetItemNameByItem(item) == szName then
				if item.nQuality > 2 and item.nGenre ~= ITEM_GENRE.BOOK then
					return _HM_Cast.Sysmsg("���ɶ���������Ʒ")
				else
					_HM_Cast.Debug("������Ʒ [" .. dwBox .. "," .. dwX .. "]")
					DestroyItem(dwBox, dwX)
				end
			end
		end
	end
end

-- ȡ�����ϵ�ĳ�� Buff
_HM_Cast.CancelBuff = function(szName)
	if szName and szName ~= "" then
		local me = GetClientPlayer()
		local buf = _HM_Cast.GetBuffList(me, "inbuff")[szName]
		if buf and buf.bCanCancel then
			me.CancelBuff(buf.nIndex)
			_HM_Cast.Debug2("ȡ������ BUFF [" .. szName .. "]")
		else
			_HM_Cast.Debug2("û�ҵ����� BUFF [" .. szName .. "]")
		end
	end
end

-- ����Ƶ��
_HM_Cast.tTalkChannel = {
	["����"] = PLAYER_TALK_CHANNEL.NEARBY,			["��ͼ"] = PLAYER_TALK_CHANNEL.SENCE,
	["ս��"] = PLAYER_TALK_CHANNEL.BATTLE_FIELD,	["����"] = PLAYER_TALK_CHANNEL.FORCE,
	["��Ӫ"] = PLAYER_TALK_CHANNEL.CAMP,				["����"] = PLAYER_TALK_CHANNEL.WORLD,
	["����"] = PLAYER_TALK_CHANNEL.FRIENDS,			["ͬ��"] = PLAYER_TALK_CHANNEL.TONG_ALLIANCE,
	["����"] = PLAYER_TALK_CHANNEL.TEAM,				["�Ŷ�"] = PLAYER_TALK_CHANNEL.RAID,
	["���"] = PLAYER_TALK_CHANNEL.TONG,				["����"] = PLAYER_TALK_CHANNEL.WHISPER,
	["����"] = PLAYER_TALK_CHANNEL.WHISPER,
}

-- ����
_HM_Cast.Say = function(szArg, dwTarget, cond)
	local me, tar, ttar = _HM_Cast.me, nil, nil
	local szText = szArg or "Hello $mb"
	local nChannel, nTeamSize, nTeamMax = PLAYER_TALK_CHANNEL.NEARBY, 1, 5
	-- ��ȡĿ��
	if dwTarget then
		tar = HM.GetTarget(dwTarget)
	end
	if not tar then
		tar = _HM_Cast.tar
	end
	if tar then
		ttar = GetTargetHandle(tar.GetTarget())
	end
	-- �Ŷ�����
	if me.IsInParty() then
		nTeamSize = GetClientTeam().GetTeamSize()
		nTeamMax = GetClientTeam().nGroupNum * 5
	end
	-- ��ȡ����
	if cond then
		-- delay
		local arg = cond:GetArg("delay")
		if arg then
			arg = tonumber(arg) or 1
			if (GetTime() - _HM_Cast.nLastSayTime) < (arg * 1000) then
				return _HM_Cast.Debug("���Թ���Ƶ���ķ��� [delay:" .. arg .. "]")
			end
		end
		_HM_Cast.nLastSayTime = GetTime()
		-- pindao
		local arg = cond:GetArg("pindao")
		if arg and _HM_Cast.tTalkChannel[arg] then
			nChannel = _HM_Cast.tTalkChannel[arg]
			if nChannel == PLAYER_TALK_CHANNEL.WHISPER and tar then
				nChannel = tar.szName
			end
		end
		-- teamsize
		local arg = cond:GetArg("teamsize")
		if arg then
			nTeamMax = tonumber(arg) or 5
		end
		-- to
		local arg = cond:GetArg("to")
		if arg == "$mb" and tar then
			nChannel = tar.szName
		elseif arg == "$zj" then
			nChannel = me.szName
		elseif arg == "$mmb" and ttar then
			nChannel = ttar.szName
		elseif arg and arg ~= "" then
			nChannel = arg
		end
	end
	-- �滻��$zj, $mb, $n, $k, $mmb
	szText = string.gsub(szText, "%$zj", me.szName)
	if tar then
		szText = string.gsub(szText, "%$mb", tar.szName)
	end
	if ttar then
		szText = string.gsub(szText, "%$mmb", ttar.szName)
	end
	szText = string.gsub(szText, "%$n", nTeamSize)
	szText = string.gsub(szText, "%$k", nTeamMax - nTeamSize)
	HM.Talk(nChannel, szText)
end

---------------------------------------------------------------------
-- ��չ�����б�
---------------------------------------------------------------------
_HM_Cast.tExtendSkill = {
	["��"] = 9007,
	["ѡĿ��"] = function(arg, id, cond)
		local dwType, dwID = _HM_Cast.FindTarget(cond)
		if dwType then
			_HM_Cast.SetTarget(dwType, dwID)
		end
	end,
	["ѡ�Լ�"] = function() SetTarget(TARGET.PLAYER, GetClientPlayer().dwID) end,
	["ͣ��"] = function() _HM_Cast.bStop = true end,
	["�ж϶���"] = function() GetClientPlayer().StopCurrentAction() end,
	["������Ʒ"] = function(arg) _HM_Cast.DropBagItem(arg) end,
	["��������"] = function() _HM_Cast.bProChannel = true end,
	["����������"] = function() _HM_Cast.bProChannel = false end,
	["ȡ��buff"] = _HM_Cast.CancelBuff,
	["˵��"] = _HM_Cast.Say,
	["goto"] = function(arg) _HM_Cast.szGotoLabel = arg end,
	["label"] = function(arg) if arg and _HM_Cast.szGotoLabel == arg then _HM_Cast.szGotoLabel = nil end end,
}
_HM_Cast.tExtendSkill["select"] = _HM_Cast.tExtendSkill["ѡĿ��"]
_HM_Cast.tExtendSkill["say"] = _HM_Cast.tExtendSkill["˵��"]
---------------------------------------------------------------------
-- ǰ��ִ�м��ܣ������������жϣ�
---------------------------------------------------------------------
_HM_Cast.tSuperSkill = {
	["debug"] = function()
		if HM_About then
			HM_About.bDebug = not HM_About.bDebug
			if HM_About.bDebug then
				_HM_Cast.Sysmsg("�򿪵�����Ϣ")
			else
				_HM_Cast.Sysmsg("�رյ�����Ϣ")
			end
		end
	end,
	["alias"] = function(cond, arg)
		if not cond or not arg or arg == "" then
			_HM_Cast.Sysmsg("alias ָ����Ҫ����")
		elseif _HM_Cast.tCondFunc[arg] or _HM_Cast.tCondArg[arg] then
			_HM_Cast.Sysmsg("alias ���� [" .. arg .. "] �������ж�����")
		else
			_HM_Cast.tCondCache[arg] = cond:Check()
		end
	end,
}

---------------------------------------------------------------------
-- �ɺ�������д��
---------------------------------------------------------------------
-- ���＼������Ч
local PET_NORMAT_SKILL_COUNT = 6
local function GetPetActionBarSkillAnimate(nIndex)
	local hFrame = Station.Lookup("Normal/PetActionBar")
	if nIndex > hFrame.nCount then
		return
	end
	local hTotalHandle = hFrame:Lookup("", "")
	local hBox = hTotalHandle:Lookup("Handle_Box/Handle_SkillMod")
	local hAnimate = nil
	if nIndex <= PET_NORMAT_SKILL_COUNT then
		hAnimate = hBox:Lookup("Animate_Skills" .. nIndex)
	else
		local hSkillHandle = hBox:Lookup("Handle_OtherSkill/Handle_SkillBox" .. nIndex)
		if hSkillHandle then
			hAnimate =  hSkillHandle:Lookup("Animate_Skill")
		end
	end
	return hAnimate
end

-- ��ȡ���Ż��ؼ���
local PUPPET_SKILL_COUNT = 8
local function Table_GetPuppetSkill(dwNpcTemplateID)
	local tPuppetSkill = g_tTable.PuppetSkill:Search(dwNpcTemplateID)
	if not tPuppetSkill then
		return
	end
	local tSkill = {}
	for i = 1, PUPPET_SKILL_COUNT do
		if tPuppetSkill["nSkillID" .. i] <= 0 then
			break
		end
		table.insert(tSkill, {tPuppetSkill["nSkillID" .. i], tPuppetSkill["nLevel" .. i]})
	end
	return tSkill
end

-- ɾ����Ʒ
local function DestroyItem(dwBox, dwX)
	local frame = Station.Lookup("Normal/BigBagPanel")
	if not frame then
		return _HM_Cast.Sysmsg("���ȴ�һ�α������ܶ�����Ʒ")
	end
	local handle = frame:Lookup("", "Handle_Bag_Normal/Handle_Bag" .. dwBox .. "/Handle_Bag_Content" .. dwBox)
	if not handle then
		return
	end
	local box = handle:Lookup(dwX)
	if not box then
		return _HM_Cast.Sysmsg("�뽫�����л�����ͨģʽ")
	end
	Hand_Pick(box:Lookup(1))
	Hand_DropHandObj()
	HM.DoMessageBox("DropItemSure")
end

-- ��ȡ�����ӵ���λ
local function WeaponBag_GetFreeBox()
	local player = GetClientPlayer()
	local nBoxSize = player.GetBoxFreeRoomSize(INVENTORY_INDEX.BULLET_PACKAGE)
	for dwX = 0, nBoxSize - 1 do
		local item = player.GetItem(INVENTORY_INDEX.BULLET_PACKAGE, dwX)
		if not item then
			return INVENTORY_INDEX.BULLET_PACKAGE, dwX
		end
	end
end

---------------------------------------------------------------------
-- ���ܼ��ء�ִ��
---------------------------------------------------------------------
-- ɨ��Ŀ��������� ��������ɨ��������
_HM_Cast.IsSearchPrefix = function(c)
	return c == "%" or c == "#" or c == "~" or c == "<" or c == ">"
end

-- ��Ҫ������������������
_HM_Cast.IsBrokenPrefix = function(c)
	return c == "^" or c == "@" or c == "_" or c == "#" or c == "~" or c == "<" or c == ">"
end

-- ���ᵼ���޸�ִ�������ľ�̬��������ֱ���ж�����
_HM_Cast.IsStaticPrefix = function(c)
	return not c or c == "#" or c == "^" or c == "$"
end

-- �жϼ����Ƿ�Ϊ˲��
_HM_Cast.IsImmSkill = function(dwSkillID, dwLevel)
	if dwSkillID == 605 or HM.GetChannelSkillFrame(dwSkillID) then
		return false
	end
	local info = GetSkillInfo(GetClientPlayer().GetSkillRecipeKey(dwSkillID, dwLevel))
	return info ~= nil and info.CastTime == 0
end

-- �������ƻ�ȡ������ؼ���
_HM_Cast.GetPetSkill = function(szName)
	local me, aSkill = GetClientPlayer(), {}
	if _HM_Cast.dwBatteryID then
		local npc = GetNpc(_HM_Cast.dwBatteryID)
		if npc then
			aSkill = Table_GetPuppetSkill(npc.dwTemplateID)
		end
	else
		local npc = me.GetPet()
		if npc then
			aSkill = Table_GetPetSkill(npc.dwTemplateID)
		end
	end
	for k, v in ipairs(aSkill) do
		if szName == Table_GetSkillName(v[1], v[2]) then
			local nLevel = me.GetSkillLevel(v[1])
			if nLevel == 0 then
				nLevel = v[2]
			end
			_HM_Cast.Debug2("�������/���ؼ��� [" .. szName .. "]")
			_HM_Cast.nPetSkillIndex = k
			return GetSkill(v[1], nLevel)
		end
	end
end

-- ���뼼���б����˱������ܺ����ؼ���
_HM_Cast.LoadAllSkill = function()
	local tSkill, nCount, me = {}, 0, GetClientPlayer()
	-- ��չ����
	for k, v in pairs(_HM_Cast.tExtendSkill) do
		if type(v) == "number" then
			local n = me.GetSkillLevel(v)
			if not n or n == 0 then
				n = 1
			end
			v = GetSkill(v, n)
		end
		if v then
			tSkill[k] = v
			nCount = nCount + 1
			_HM_Cast.Debug2("������չ���� [" .. k .. "]")
		end
	end
	-- ���漼��
	local aSkill = me.GetAllSkillList() or {}
	for k, v in pairs(aSkill) do
		local v = GetSkill(k, v)
		if v then
			k = Table_GetSkillName(v.dwSkillID, v.dwLevel)
			if k and not v.bIsPassiveSkill then
				tSkill[k] = v
				nCount = nCount + 1
				_HM_Cast.Debug2("���볣�漼�� [" .. k .. "](#" .. v.dwSkillID .. ", Lv" .. v.dwLevel .. ")")
			end
		end
	end
	_HM_Cast.Sysmsg("������ü��� [" .. nCount .. "] ����")
	return tSkill
end

-- ������Ʒ�б�
_HM_Cast.LoadAllItem = function()
	local me, tItem = GetClientPlayer(), {}
	for dwBox = 0, BigBagPanel_nCount, 1 do
		local dwSize = me.GetBoxSize(dwBox) or 0
		for dwX = 0, dwSize - 1 do
			local item = me.GetItem(dwBox, dwX)
			if item and not tItem[item.szName] then
				local szName = GetItemNameByItem(item)
				tItem[szName] = { dwBox, dwX, item.dwTabType, item.dwIndex }
			end
		end
	end
	return tItem
end

-- �������ƻ�ȡ��Ʒλ��
_HM_Cast.GetItem = function(szName)
	if not _HM_Cast.tItem then
		_HM_Cast.tItem = _HM_Cast.LoadAllItem()
	end
	return _HM_Cast.tItem[szName]
end

-- �������ƻ�ȡ������/��Ʒ/������������
_HM_Cast.GetSkill = function(szName)
	-- ���ؼ����б�
	if not _HM_Cast.tSkill then
		_HM_Cast.tSkill = _HM_Cast.LoadAllSkill()
	end
	_HM_Cast.nPetSkillIndex = nil
	-- ������������ĸ���֣�48~57, 65~90, 97~122)
	local nByte, szPrefix = string.byte(szName, 1, 1), nil
	if nByte < 48 or (nByte > 57 and nByte < 65) or (nByte > 90 and nByte < 97) or (nByte > 122 and nByte < 128) then
		szPrefix = string.sub(szName, 1, 1)
		szName = string.sub(szName, 2)
	end
	-- ���ָܷ��
	if _HM_Cast.tSkillAlias[szName] then
		szName = _HM_Cast.tSkillAlias[szName]
	end
	local me, aSkill = GetClientPlayer(), SplitString(szName, "|")
	for _, v in ipairs(aSkill) do
		local skill = _HM_Cast.tSkill[v] or _HM_Cast.GetPetSkill(v)
		if not skill then	-- check as item
			local it = _HM_Cast.GetItem(v)
			if not it then
				_HM_Cast.Debug("��Ч�ļ���/��Ʒ [" .. v .. "]")
			else
				local _, nLeft = me.GetItemCDProgress(it[1], it[2])
				if nLeft ~= 0 then
					_HM_Cast.Debug2("����δ��ȴ��Ʒ [" .. v .. "]")
				else
					skill = it
				end
			end
		elseif type(skill) ~= "function" then
			local _, nLeft = me.GetSkillCDProgress(skill.dwSkillID, skill.dwLevel)
			if nLeft ~= 0 then
				skill = nil
				_HM_Cast.Debug2("����δ��ȴ���� [" .. v .. "]")
			elseif _HM_Cast.IsStaticPrefix(szPrefix) and not HM.CanUseSkill(skill.dwSkillID, skill.dwLevel) then
				skill = nil
				_HM_Cast.Debug2("����δͨ�� UITest ���� [" .. v .. "]")
			end
		end
		if skill then
			_HM_Cast.Debug2("��ÿ��ü���/��Ʒ [" .. v .. "]")
			return skill, szPrefix
		end
	end
end

-- �ͷż���
_HM_Cast.CastSkill = function(dwSkillID, dwLevel)
	return OnAddOnUseSkill(dwSkillID, dwLevel)
end

-- ʹ����Ʒ data = { dwBox, dwX, dwTabType, dwIndex }
_HM_Cast.UseItem = function(data)
	if data[1] ~= INVENTORY_INDEX.EQUIP then
		local item = GetPlayerItem(GetClientPlayer(), data[1], data[2])
		if item and item.nGenre == ITEM_GENRE.EQUIPMENT then
			if item.nSub == EQUIPMENT_SUB.BULLET then
				local dwBox, dwX = WeaponBag_GetFreeBox()
				if dwBox and dwX then
					OnExchangeItem(data[1], data[2], dwBox, dwX, item.nStackNum)
				end
			else
				local eRetCode, nEquipPos = GetClientPlayer().GetEquipPos(data[1], data[2])
				if eRetCode == 1 then	-- ITEM_RESULT_CODE.SUCCESS
					OnExchangeItem(data[1], data[2], INVENTORY_INDEX.EQUIP, nEquipPos)
				else
					OutputMessage("MSG_ANNOUNCE_RED", g_tStrings.tItem_Msg[eRetCode])
				end
			end
			return
		end
	end
	return OnUseItem(data[1], data[2])
end

-- �л�Ŀ��
_HM_Cast.SetTarget = function(dwType, dwID)
	if dwID == 0 and HM_Locker and HM_Locker.bLockFight then
		HM_Locker.bLockFight = false
		SetTarget(dwType, dwID)
		HM_Locker.bLockFight = true
	else
		SetTarget(dwType, dwID)
	end
end

-- ����������
_HM_Cast.HandlePrefix = function(szPrefix, tarType, tarID, sCond)
	if szPrefix then
		_HM_Cast.Debug2("���������ַ� [" .. szPrefix .. "]")
		if szPrefix == "_" and _HM_Cast.tar then
			-- �Կ�Ŀ��
			return TARGET.NO_TARGET, 0
		elseif szPrefix == "^" then
			-- �ж��Լ�������2���������ܣ�
			_HM_Cast.me.StopCurrentAction()
		end
	end
	return tarType, tarID
end

-- ��ִ����ں���
_HM_Cast.Cast = function(szInput)
	local nFrame = GetLogicFrameCount()
	if nFrame ~= _HM_Cast.nLastCastFrame then
		-- clean cache & flags
		_HM_Cast.bStop = false
		_HM_Cast.bProChannel = true
		_HM_Cast.tCondCache = {}
		_HM_Cast.szGotoLabel = nil
		_HM_Cast.nLastCastFrame = nFrame
		-- has delay cast
		if _HM_Cast.tDelayCast then
			return _HM_Cast.Debug2("�ȴ��ӳٵ���1 [" .. table.concat(_HM_Cast.tDelayCast, ",") .. "]")
		end
	end
	-- ������������������ܡ�����
	local xCond, szSkill, szArg = _HM_Cast.ParseInput(szInput)
	if not szSkill then
		return
	end
	local tarType, tarID = GetClientPlayer().GetTarget()
	_HM_Cast.me = GetClientPlayer()
	_HM_Cast.tar = GetTargetHandle(tarType, tarID)
	-- goto label
	if _HM_Cast.szGotoLabel and szSkill ~= "label" then
		return _HM_Cast.Debug2("�ȴ���ת�� [" .. _HM_Cast.szGotoLabel .. "]������ [" .. szSkill .. "]")
	end
	-- super skill
	local fnSuper= _HM_Cast.tSuperSkill[szSkill]
	if fnSuper then
		return fnSuper(xCond, szArg)
	end
	-- load skill
	local skill, szPrefix = _HM_Cast.GetSkill(szSkill)
	if not skill then
		return
	end
	local nState = _HM_Cast.me.GetOTActionState()
	if _HM_Cast.bProChannel and nState == 2 and not _HM_Cast.IsBrokenPrefix(szPrefix) then
		return _HM_Cast.Debug2("���������У����� [" .. szSkill .. "]")
	end
	if szPrefix and _HM_Cast.tDelayCast then
		return _HM_Cast.Debug2("�ȴ��ӳٵ���2������ [" .. szSkill .. "]")
	end
	-- ��ͨ���ܣ����ͣ�֣�����
	local bExtend = true
	if type(skill) ~= "function" then
		bExtend = false
		if _HM_Cast.bStop then
			return _HM_Cast.Debug2("��ͣ�֣����� [" .. szSkill .. "]")
		end
		if nState ~= 0 and nState ~= 2 and not _HM_Cast.IsBrokenPrefix(szPrefix) then
			return _HM_Cast.Debug2("�����У����� [" .. szSkill .. "]")
		end
	end
	-- ��ʼ����������
	local sCond = nil
	if _HM_Cast.IsSearchPrefix(szPrefix) or szSkill == "select" or szSkill == "ѡĿ��" then
		if not szArg or szPrefix == "%" then
			sCond, xCond = xCond, nil
		else
			sCond = _HM_Cast.ParseArg(szArg)
		end
	end
	-- ���ִ������
	if xCond and not xCond:Check(bExtend) then
		return _HM_Cast.Debug2("���������������� [" .. szSkill .. "]")
	end
	-- ��������Ŀ��ִ����չ����
	if szPrefix == "%" and bExtend then
		_HM_Cast.Debug("����ִ����չ���� [" .. szSkill .. "]")
		return _HM_Cast.WalkTarget(szArg, sCond, skill)
	end
	-- ���������ַ�����ȡ��Ŀ�꣩
	local bRestar = false
	local newTarType, newTarID = _HM_Cast.HandlePrefix(szPrefix, tarType, tarID, sCond)
	if not newTarType then
		return _HM_Cast.Debug("�Ҳ�������Ŀ�꣬���� [" .. szSkill .. "]")
	elseif newTarID ~= tarID then
		_HM_Cast.Debug("����Ŀ�� [#" .. tarID .. " -> #" .. newTarID .. "]")
		_HM_Cast.SetTarget(newTarType, newTarID)
		if nState ~= 0 then	-- ��Ŀ��Ļ���ǿ����ֹ����
			_HM_Cast.me.StopCurrentAction()
		end
		-- ���� > ������������Ӧ�ûָ�Ŀ��
		if szPrefix ~= ">" then
			-- ����Ƕ����������Ӻ�ԭ
			if not bExtend and skill.dwSkillID and not _HM_Cast.IsImmSkill(skill.dwSkillID, skill.dwLevel) then
				_HM_Cast.tDelayCast = { "RESTAR", nFrame + 6, tarType, tarID, newTarID }
			else
				bRestar = true
			end
		end
	end
	-- ִ�м���
	local xRet = nil
	if bExtend then
		_HM_Cast.Debug("������չ [" .. szSkill .. "]")
		xRet = skill(szArg, newTarID, sCond or xCond)
	elseif type(skill) == "table" and #skill == 4 then
		_HM_Cast.Debug("ʹ����Ʒ [" .. szSkill .. "]")
		xRet = _HM_Cast.UseItem(skill)
	else
		_HM_Cast.Debug("�ͷż��� [" .. szSkill .. "]")
		if _HM_Cast.IsStaticPrefix(szPrefix) or HM.CanUseSkill(skill.dwSkillID, skill.dwLevel) then
			_HM_Cast.Debug("�ɹ��ͷż��� [" .. szSkill .. "]")
			xRet = _HM_Cast.CastSkill(skill.dwSkillID, skill.dwLevel)
			-- ��Χѡ��SKILL_CAST_MODE.POINT_AREA = 5��SKILL_CAST_MODE.POINT = 8
			if skill.nCastMode == 5 or skill.nCastMode == 8 then
				local tar = GetTargetHandle(newTarType, newTarID) or _HM_Cast.me
				_HM_Cast.Debug2("�Զ�ѡ��Χ (" .. tar.nX .. ", " .. tar.nY .. ", " .. tar.nZ .. ")")
				UserSelect.DoSelectPoint(tar.nX, tar.nY, tar.nZ)
			end
		else
			szPrefix = nil	-- ǿ�ƺ��Բ����� $ �����ַ�
			_HM_Cast.Debug("�޷��ͷż��� [" .. szSkill .. "]")
		end
	end
	-- ��ԭĿ��
	if bRestar then
		_HM_Cast.SetTarget(tarType, tarID)
	end
	-- ��ֹ���
	if szPrefix == "$" then
		_HM_Cast.bStop = true
		_HM_Cast.Debug2("��ִֹ���������")
		return false
	end
	return xRet
end

---------------------------------------------------------------------
-- �¼�������
---------------------------------------------------------------------
-- ����ѭ��
_HM_Cast.OnBreathe = function()
	-- �ӳٵ���
	if _HM_Cast.tDelayCast then
		local nFrame, me = GetLogicFrameCount(), GetClientPlayer()
		local data = _HM_Cast.tDelayCast
		if not data[2] or data[2] <= nFrame then
			local bSkip = false
			if data[1] == "RESTAR" then
				if me.GetOTActionState() ~= 0 then
					bSkip = true
				else
					local _, tarID = me.GetTarget()
					if tarID == data[5] then
						_HM_Cast.Debug("��ԭĿ�� [#" .. tarID .. " -> #" .. data[4] .. "]")
						_HM_Cast.SetTarget(data[3], data[4])
					end
				end
			end
			if not bSkip then
				_HM_Cast.tDelayCast = nil
			end
		end
	end
end

-- NPC enter
_HM_Cast.OnNpcEnter = function()
	-- ǧ���䣺16174~16177
	local npc = GetNpc(arg0)
	if npc and npc.dwTemplateID >= 16174 and npc.dwTemplateID <= 16177
		and npc.dwEmployer == GetClientPlayer().dwID
	then
		_HM_Cast.dwBatteryID = npc.dwID
	end
end

-- NPC Leave
_HM_Cast.OnNpcLeave = function()
	if arg0 == _HM_Cast.dwBatteryID then
		_HM_Cast.dwBatteryID = nil
	end
end

-- �ͷż���	��arg0 = dwCaster��arg1 = dwSkillID��arg2 = dwLevel��
_HM_Cast.OnSkillCast = function(dwCaster, dwID, dwLevel, szEvent)
	local nChannel = HM.GetChannelSkillFrame(dwID)
	if nChannel then
		local nFrame = GetLogicFrameCount()
		for k, v in pairs(_HM_Cast.tLogChannel) do
			if (nFrame - v[3]) > v[4] then
				_HM_Cast.tLogChannel[k] = nil
			end
		end
		_HM_Cast.tLogChannel[dwCaster] = { dwID, dwLevel, nFrame, nChannel }
	end
end

-- ϵͳ��Ϣ
_HM_Cast.OnSysMsg = function()
	if arg0 == "UI_OME_FINISH_DUEL" then
		_HM_Cast.dwDuelID = nil
	elseif arg0 == "UI_OME_START_DUEL" then
		_HM_Cast.dwDuelID = arg1
	elseif arg0 == "UI_OME_SKILL_HIT_LOG" and arg3 == SKILL_EFFECT_TYPE.SKILL then
		_HM_Cast.OnSkillCast(arg1, arg4, arg5, arg0)
	elseif arg0 == "UI_OME_SKILL_EFFECT_LOG" and arg4 == SKILL_EFFECT_TYPE.SKILL then
		_HM_Cast.OnSkillCast(arg1, arg5, arg6, arg0)
	end
end

-- ս����ʾ
_HM_Cast.OnFightHint = function()
	if arg0 then
		_HM_Cast.nFightBegin = GetTime()
	else
		_HM_Cast.nFightBegin = nil
	end
end

-- ����ͼ
_HM_Cast.OnLoadingEnd = function()
	_HM_Cast.nLastSayTime = 0
	_HM_Cast.nLastSelTime = 0
	_HM_Cast.nLastCastFrame = 0
	_HM_Cast.tDelayCast = nil
	_HM_Cast.tLogChannel = {}
end

---------------------------------------------------------------------
-- ���������庯��
---------------------------------------------------------------------
_HM_Cast.PS = {}

-- init panel
_HM_Cast.PS.OnPanelActive = function(frame)
	local ui, nX = HM.UI(frame), 0
	-- features
	ui:Append("Text", { txt = _L["Feature setting"], font = 27 })
	ui:Append("WndCheckBox", { txt = "���� PVE ����չ����ȡ����С�˲���Ч��", x = 10, y = 28, checked = HM_Cast.bEnable })
	:Click(function(bChecked)
		HM_Cast.bEnable = bChecked
		if bChecked then
			AppendCommand("cast", _HM_Cast.Cast)
		end
	end)
	-- tips
	ui:Append("Text", { txt = _L["Tips"], x = 0, y = 64, font = 27 })
	nX = ui:Append("Text", { txt = "1. �ڹٷ��� /cast ����չ֧�ָ����жϺ�α����", x = 10, y = 92 }):Pos_()
	ui:Append("WndButton", { txt = "��ϸ˵��", x = nX + 5, y = 92 }):Click(function()
		OpenInternetExplorer("http://haimanchajian.com/MACRO.txt")
	end)
	ui:Append("Text", { txt = "2. ������չԴ��л���κ���ʽ���޸ĺ��ٷ���", font = 50, x = 10, y = 120 })
	ui:Append("Text", { txt = "3. �޷������Ŀ���ͷż��ܣ��﷨�������ݺ��Ӻʹ�ź�", x = 10, y = 148 })
	ui:Append("Text", { txt = "4. �йغ�������ͽ����������ٶ����ɣ��������", x = 10, y = 176 })
end

---------------------------------------------------------------------
-- ȫ�ִ���
---------------------------------------------------------------------
RegisterEvent("NPC_ENTER_SCENE", _HM_Cast.OnNpcEnter)
RegisterEvent("NPC_LEAVE_SCENE", _HM_Cast.OnNpcLeave)
RegisterEvent("SKILL_UPDATE", function() _HM_Cast.tSkill = nil end)
RegisterEvent("BAG_ITEM_UPDATE", function() _HM_Cast.tItem = nil end)
RegisterEvent("EQUIP_ITEM_UPDATE", function() _HM_Cast.tItem = nil end)
RegisterEvent("SYNC_ROLE_DATA_END", function() _HM_Cast.tItem = nil end)
RegisterEvent("DO_SKILL_CAST", function() _HM_Cast.OnSkillCast(arg0, arg1, arg2) end)
RegisterEvent("SYS_MSG", _HM_Cast.OnSysMsg)
RegisterEvent("FIGHT_HINT", _HM_Cast.OnFightHint)
RegisterEvent("LOADING_END", _HM_Cast.OnLoadingEnd)
RegisterEvent("CUSTOM_DATA_LOADED", function()
	if arg0 == "Role" and HM_Cast.bEnable then
		AppendCommand("cast", _HM_Cast.Cast)
	end
end)
HM.BreatheCall("HM_Cast", _HM_Cast.OnBreathe)
HM.RegisterPanel(_HM_Cast.szTitle, 529, _L["Battle"], _HM_Cast.PS)

-- ��ִ�нӿڣ��ɹ����ã�
HM_Cast.Cast = _HM_Cast.Cast

-- ��ȡ���ر��������ԣ�
HM_Cast.GetLocalVar = function(szName)
	if szName then
		return _HM_Cast[szName]
	end
	return _HM_Cast
end

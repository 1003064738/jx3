--
-- ���������ְҵ��ɫ��ǿ������������м��������������ܶ��Լ���̫����
--

HM_Force = {
	bHorsePage = true,	-- �������л�������������ߣ�
	bSelfTaiji = true,			-- ���ܶ��Լ���̫������������
	bSelfTaiji2 = false,		-- ��Զֻ���Լ���̫��
	bAlertPet = true,			-- �嶾������ʧ����
	bAutoDance = true,	-- �����Զ�����
	bAutoXyz = true,		-- �Զ���Ŀ��ִ�з�Χָ����
	bAutoXyzSelf = true,	-- �Զ����Լ���
	bShowJW = true,			-- ��ʾ�������
	tSelfQC = { [358] = true },	-- Ĭ��ֻ����̫��
}

for k, _ in pairs(HM_Force) do
	RegisterCustomData("HM_Force." .. k)
end

---------------------------------------------------------------------
-- ���غ����ͱ���
---------------------------------------------------------------------
local _HM_Force = {
	nFrameXJ = 0,
}

-- qichang
_HM_Force.tQC = {
	[357] = { dwBuffID = 373 },
	[358] = { dwBuffID = 374 },
	[359] = { dwBuffID = 375 },
	[360] = { dwBuffID = 376 },
	[361] = { dwBuffID = 561 },
	[362] = { dwBuffID = 378 },
}

-- get qc menu
_HM_Force.GetQCMenu = function()
	local m0 = {}
	for k, v in pairs(_HM_Force.tQC) do
		table.insert(m0, { szOption = HM.GetSkillName(k), bCheck = true, bChecked = HM_Force.tSelfQC[k],
			fnAction = function (d, b) HM_Force.tSelfQC[k] = b end
		})
	end
	return m0
end

-- check buff by dwBuffID
_HM_Force.HasBuff = function(dwBuffID, bCanCancel)
	local tBuff = GetClientPlayer().GetBuffList() or {}
	for _, v in ipairs(tBuff) do
		if v.dwID == dwBuffID and (bCanCancel == nil or bCanCancel == v.bCanCancel) then
			return true
		end
	end
	return false
end

-- use non-target skill
_HM_Force.OnUseEmptySkill = function(dwID)
	local me = GetClientPlayer()
	if me and HM.CanUseSkill(dwID) then
		local tarType, tarID = me.GetTarget()
		if tarID ~= 0 and tarType == TARGET.PLAYER then
			if TargetPanel_SetOpenState then
				TargetPanel_SetOpenState(true)
			end
			HM.SetTarget(-1)
		end
		OnAddOnUseSkill(dwID, 1)
		HM.SetTarget(tarType, tarID)
		if TargetPanel_SetOpenState then
			TargetPanel_SetOpenState(false)
		end
		return true
	end
end

-- check horse page
_HM_Force.OnRideHorse = function()
	if HM_Force.bHorsePage then
		local me = GetClientPlayer()
		if me then
			local mnt = me.GetKungfuMount()
			if mnt and mnt.dwMountType == 1 then
				local nPage = GetUserPreferences(1390, "c")
				if me.bOnHorse and nPage ~= 3 then
					SelectMainActionBarPage(3)
				elseif not me.bOnHorse and nPage ~= 1 then
					SelectMainActionBarPage(1)
				end
			end
		end
	end
end

-- check pet of 5D ��XJ��2226��
_HM_Force.OnNpcLeave = function()
	if HM_Force.bAlertPet then
		local me = GetClientPlayer()
		if me then
			local pet = me.GetPet()
			if pet and pet.dwID == arg0 and (GetLogicFrameCount() - _HM_Force.nFrameXJ) >= 32 then
				OutputWarningMessage("MSG_WARNING_YELLOW", _L("Your pet [%s] disappeared!",  pet.szName))
				PlaySound(SOUND.UI_SOUND, g_sound.CloseAuction)
			end
		end
	end
end

-- check to prepare self qc
_HM_Force.OnPrepareQC = function(dwID)
	local me, qc = GetClientPlayer(), _HM_Force.tQC[dwID]
	if HM_Force.bSelfTaiji2 or not _HM_Force.HasBuff(qc.dwBuffID, true) then
		local tarType, tarID = me.GetTarget()
		if tarID ~= 0 and tarID ~= me.dwID then -- and GetCharacterDistance(me.dwID, tarID) <= 1280 then
			HM.SetTarget(-1)
			_HM_Force.ReTarget = { tarType, tarID, GetLogicFrameCount() }
		end
	end
end

-- restore target
_HM_Force.RestoreTarget = function()
	-- restore target
	if _HM_Force.ReTarget then
		local dwType, dwID = _HM_Force.ReTarget[1], _HM_Force.ReTarget[2]
		HM.SetTarget(dwType, dwID)
		_HM_Force.ReTarget = nil
	end
end

-- auto xyz
_HM_Force.UserSelect_SelectPoint = UserSelect.SelectPoint
UserSelect.SelectPoint = function(...)
	_HM_Force.UserSelect_SelectPoint(...)
	if HM_Force.bAutoXyz then
		local tar = GetTargetHandle(GetClientPlayer().GetTarget())
		if tar and (HM_Force.bAutoXyzSelf or tar.dwID ~= GetClientPlayer().dwID) then
			UserSelect.DoSelectPoint(tar.nX, tar.nY, tar.nZ)
		end
	end
end

-- breathe loop
_HM_Force.OnBreathe = function()
	local me = GetClientPlayer()
	if not me or not me.GetKungfuMount() or me.GetOTActionState() ~= 0 then
		return
	end
	if me.GetKungfuMount().dwMountType == 4 then
		-- auto dance
		if HM_Force.bAutoDance and me.nAccumulateValue == 0
			and (me.nMoveState == MOVE_STATE.ON_STAND or me.nMoveState == MOVE_STATE.ON_FLOAT)
		then
			return HM_Force.OnUseEmptySkill(537)
		end
	end
end

-- bind QX button
_HM_Force.BindQXBtn = function()
	local btn = Player_GetFrame():Lookup("", "Handle_QiXiu"):Lookup("Image_QX_Btn")
	if btn then
		btn.OnItemLButtonDown = function()
			HM_Force.bAutoDance = not HM_Force.bAutoDance
			if HM_Force.bAutoDance then
				HM.Sysmsg(_L["Enable auto sword dance"])
			else
				local aBuff = GetClientPlayer().GetBuffList()
				for _,v in pairs(aBuff) do
					if v.dwID == 409 then
						GetClientPlayer().CancelBuff(v.dwID)
						break
					end
				end
				HM.Sysmsg(_L["Disable auto sword dance"])
			end
			this.bClickDown = true
		end
	end
end

-- show jw or not
_HM_Force.ShowJWBuff = function()
	for i = 1, 10 do
		local buff = Table_GetBuff(409, i)
		if HM_Force.bShowJW then
			buff.bShow = 1
		else
			buff.bShow = 0
		end
	end
end

-------------------------------------
-- ���ý���
-------------------------------------
_HM_Force.PS = {}

-- init panel
_HM_Force.PS.OnPanelActive = function(frame)
	local ui = HM.UI(frame)
	-- cy
	ui:Append("Text", { txt = _L["Gas field"], x = 0, y = 0, font = 27 })
	ui:Append("WndCheckBox", { txt = _L["Enable smart cast gas skill to myself"], checked = HM_Force.bSelfTaiji })
	:Pos(10, 28):Click(function(bChecked)
		HM_Force.bSelfTaiji = bChecked
		ui:Fetch("Check_Only"):Enable(bChecked)
		ui:Fetch("Combo_QC"):Enable(bChecked)
	end)
	local nX = ui:Append("WndCheckBox", "Check_Only", { txt = _L["Always cast gas skill to myself (for QC)"], checked = HM_Force.bSelfTaiji2 })
	:Pos(10, 56):Enable(HM_Force.bSelfTaiji):Click(function(bChecked)
		HM_Force.bSelfTaiji2 = bChecked
	end):Pos_()
	local nX = ui:Append("WndComboBox", "Combo_QC", { txt = _L["Select gas skill"], w = 150, h = 25 })
	:Pos(nX + 10, 56):Enable(HM_Force.bSelfTaiji):Menu(_HM_Force.GetQCMenu)
	-- other
	ui:Append("Text", { txt = _L["Others"], x = 0, y = 92, font = 27 })
	nX = ui:Append("Text", { txt = _L["Commands to jump back, small dodge: "], x = 12, y = 120 }):Pos_()
	ui:Append("Text", { txt = "/" .. _L["JumpBack"] .. "   /" .. _L["SmallDodge"], x = nX, y = 120, font = 57 })
	ui:Append("WndCheckBox", { txt = _L["Auto swith actionbar page of horse states (for TC, bind to P.1/3)"], checked = HM_Force.bHorsePage })
	:Pos(10, 148):Click(function(bChecked)
		HM_Force.bHorsePage = bChecked
	end)
	ui:Append("WndCheckBox", { txt = _L["Alert when pet disappear unexpectedly (for 5D)"], checked = HM_Force.bAlertPet })
	:Pos(10, 176):Click(function(bChecked)
		HM_Force.bAlertPet = bChecked
	end)
	ui:Append("WndCheckBox", { txt = _L["Auto enter dance status (Click fan on player panel to switch)"], checked = HM_Force.bAutoDance })
	:Pos(10, 204):Click(function(bChecked)
		HM_Force.bAutoDance = bChecked
	end)
	nX = ui:Append("WndCheckBox", { txt = _L["Cast area skill to current target directly"], checked = HM_Force.bAutoXyz })
	:Pos(10, 232):Click(function(bChecked)
		HM_Force.bAutoXyz = bChecked
		ui:Fetch("Check_XyzSelf"):Enable(bChecked)
	end):Pos_()
	ui:Append("WndCheckBox", "Check_XyzSelf", { txt = _L["Except own"], checked = not HM_Force.bAutoXyzSelf })
	:Pos(nX + 10, 232):Enable(HM_Force.bAutoXyz):Click(function(bChecked)
		HM_Force.bAutoXyzSelf = not bChecked
	end)
	ui:Append("WndCheckBox", { txt = _L["Show dance buff and its stack num of 7X"], checked = HM_Force.bShowJW })
	:Pos(10, 260):Click(function(bChecked)
		HM_Force.bShowJW = bChecked
		_HM_Force.ShowJWBuff()
	end)
end

-- conflict check
_HM_Force.PS.OnConflictCheck = function()
	if Ktemp and HM_Force.bHorsePage then
		Ktemp.bchange = false
	end
end

---------------------------------------------------------------------
-- ע���¼�����ʼ��
---------------------------------------------------------------------
-- horse
HM.RegisterEvent("NPC_LEAVE_SCENE", _HM_Force.OnNpcLeave)
HM.RegisterEvent("SYNC_ROLE_DATA_END", function()
	_HM_Force.OnRideHorse()
	_HM_Force.BindQXBtn()
	_HM_Force.ShowJWBuff()
end)
HM.RegisterEvent("PLAYER_STATE_UPDATE", function()
	if arg0 == GetClientPlayer().dwID then
		_HM_Force.OnRideHorse()
	end
end)
HM.RegisterEvent("SYS_MSG", function()
	if arg0 == "UI_OME_SKILL_CAST_LOG" then
		if HM_Force.bSelfTaiji and arg1 == GetClientPlayer().dwID and HM_Force.tSelfQC[arg2] then
		_HM_Force.OnPrepareQC(arg2)
		end
	end
end)
HM.RegisterEvent("DO_SKILL_CAST", function()
	if arg0 == GetClientPlayer().dwID then
		-- �׼��������ٻ���2965��2221 ~ 2226
		if arg1 == 2965 or (arg1 >= 2221 and arg1 <= 2226) then
			_HM_Force.nFrameXJ = GetLogicFrameCount()
		end
		_HM_Force.RestoreTarget()
	end
end)
HM.RegisterEvent("OT_ACTION_PROGRESS_BREAK", function()
	if arg0 == GetClientPlayer().dwID then
		_HM_Force.RestoreTarget()
	end
end)

-- breathe
HM.BreatheCall("HM_Force", _HM_Force.OnBreathe, 200)

-- add to HM panel
HM.RegisterPanel(_L["School feature"], 327, nil, _HM_Force.PS)

-- macro command
AppendCommand(_L["JumpBack"], function() _HM_Force.OnUseEmptySkill(9007) end)
AppendCommand(_L["SmallDodge"], function()
	for _, v in ipairs({ 9004, 9005, 9006 }) do
		if _HM_Force.OnUseEmptySkill(v) then
			break
		end
	end
end)

-- init global caller
HM_Force.OnUseEmptySkill = _HM_Force.OnUseEmptySkill
HM_Force.HasBuff = _HM_Force.HasBuff

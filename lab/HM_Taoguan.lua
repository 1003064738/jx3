--
-- ����������Զ��������չ�
--

HM_Taoguan = {
	nUseGold = 320,		-- ����ʹ�ý��ӵķ���
	nUseZJ = 1280,		-- ��ʼ�����������Źȵķ���
	bPauseNoZJ = true,	-- ȱ������������ʱͣ��
	nPausePoint = 327680,	-- ͣ�ҷ�����
	bUseJX = true,	-- �Զ��õ����ҡ�����
}

for k, _ in pairs(HM_Taoguan) do
	RegisterCustomData("HM_Taoguan." .. k)
end

---------------------------------------------------------------------
-- ���غ����ͱ���
---------------------------------------------------------------------
local _HM_Taoguan = {
	bEnable = false,
	bHaveZJ = false,
	nPoint = 0,
}

-- use bag item
_HM_Taoguan.UseBagItem = function(szName, bWarn)
	local me = GetClientPlayer()
	for i = 1, 5 do
		for j = 0, me.GetBoxSize(i) - 1 do
		local it = GetPlayerItem(me, i, j)
			if it and it.szName == szName then
				OnUseItem(i, j)
				return true
			end
		end
	end
	if bWarn then
		HM.Sysmsg("�Զ����չޣ�ȱ��[" .. szName .. "]��")
	end
end

-- switch
_HM_Taoguan.Switch = function()
	_HM_Taoguan.bEnable = not _HM_Taoguan.bEnable
	_HM_Taoguan.bHaveZJ = false
	if _HM_Taoguan.bEnable then
		HM.Sysmsg("�Զ����չޣ���")
	else
		HM.Sysmsg("�Զ����չޣ���")
	end
end

-------------------------------------
-- �¼�����
-------------------------------------
_HM_Taoguan.MonitorZP = function(szMsg)
    local _, _, nP = string.find(szMsg, "Ŀǰ���ܻ���Ϊ��(%d+)")
    if nP then
		_HM_Taoguan.nPoint = tonumber(nP)
		_HM_Taoguan.bHaveZJ = false
    end
end

_HM_Taoguan.OnNpcEnter = function()
	if not _HM_Taoguan.bEnable
		or (HM_Taoguan.bPauseNoZJ and _HM_Taoguan.nPoint >= HM_Taoguan.nUseZJ and not _HM_Taoguan.bHaveZJ)
	then
		return
	end
	local npc = GetNpc(arg0)
	if npc and npc.szName == "�����չ�" and HM.GetDistance(npc) < 4 then
		HM.SetTarget(arg0)
		if _HM_Taoguan.nPoint < HM_Taoguan.nUseGold or not _HM_Taoguan.UseBagItem("С��") then
			if not _HM_Taoguan.UseBagItem("С����", true) then
				_HM_Taoguan.bEnable = false
			end
		end
	end
end

_HM_Taoguan.OnLootItem = function()
	if arg0 == GetClientPlayer().dwID and arg2 > 2 and GetItem(arg1).szName == "÷����ǩ" then
		_HM_Taoguan.nPoint = 0
		_HM_Taoguan.bHaveZJ = false
		HM.Sysmsg("�Զ����չޣ����ֻ������㣡")
	end
end

-------------------------------------
-- ���ý���
-------------------------------------
_HM_Taoguan.PS = {}

-- init
_HM_Taoguan.PS.OnPanelActive = function(frame)
	local ui, nX = HM.UI(frame), 0
	ui:Append("Text", { txt = "��������", x = 0, y = 0, font = 27 })
	-- gold
	nX = ui:Append("Text", { txt = "����ʹ��С�𴸣��������ﵽ", x = 10, y = 28 }):Pos_()
	ui:Append("WndComboBox", "Combo_Size1", { x = nX, y = 28, w = 100, h = 25 })
	:Text(tostring(HM_Taoguan.nUseGold)):Menu(function()
		local m0 = {}
		for i = 3, 9 do
			local v = 10 * 2 ^ i
			table.insert(m0, { szOption = tostring(v), fnAction = function()
				HM_Taoguan.nUseGold = v
				ui:Fetch("Combo_Size1"):Text(tostring(v))
			end })
		end
		return m0
	end)
	-- max
	nX = ui:Append("Text", { txt = "ֹͣ�����ҹ��ӣ��������ﵽ", x = 10, y = 56 }):Pos_()
	ui:Append("WndComboBox", "Combo_Size3", { x = nX, y = 56, w = 100, h = 25 })
	:Text(tostring(HM_Taoguan.nPausePoint)):Menu(function()
		local m0 = {}
		for i = 7, 17 do
			local v = 10 * 2 ^ i
			table.insert(m0, { szOption = tostring(v), fnAction = function()
				HM_Taoguan.nPausePoint = v
				ui:Fetch("Combo_Size3"):Text(tostring(v))
			end })
		end
		return m0
	end)
	-- zj
	nX = ui:Append("Text", { txt = "ʹ�ü��ǹ��������������ﵽ", x = 10, y = 84 }):Pos_()
	nX = ui:Append("WndComboBox", "Combo_Size2", { x = nX, y = 84, w = 100, h = 25 })
	:Text(tostring(HM_Taoguan.nUseZJ)):Menu(function()
		local m0 = {}
		for i = 5, 11 do
			local v = 10 * 2 ^ i
			table.insert(m0, { szOption = tostring(v), fnAction = function()
				HM_Taoguan.nUseZJ = v
				ui:Fetch("Combo_Size2"):Text(tostring(v))
			end })
		end
		return m0
	end):Pos_()
	ui:Append("WndCheckBox", { txt = "��ȱ��ͣ��", x = nX + 10, y = 84, checked = HM_Taoguan.bPauseNoZJ })
	:Click(function(bChecked) HM_Taoguan.bPauseNoZJ = bChecked end)
	ui:Append("WndCheckBox", { txt = "�Զ��õ����н���/����", x = 10, y = 112, checked = HM_Taoguan.bUseJX })
	:Click(function(bChecked) HM_Taoguan.bUseJX = bChecked end)
	-- begin
	nX = ui:Append("WndButton", { x = 10, y = 148, txt = "��ʼ/ֹͣ�ҹ�" }):AutoSize():Click(_HM_Taoguan.Switch):Pos_()
	ui:Append("Text", { x = nX + 10, y = 148, txt = "��������أ�/����չޣ�" })
end

---------------------------------------------------------------------
-- ע���¼�����ʼ��
---------------------------------------------------------------------
RegisterMsgMonitor(_HM_Taoguan.MonitorZP, {"MSG_SYS"})
HM.BreatheCall("taoguan1", function()
	if _HM_Taoguan.bEnable then
		HM.DoMessageBox("PlayerMessageBoxCommon")
	end
end)
HM.BreatheCall("taoguan2", function()
	if _HM_Taoguan.bEnable and _HM_Taoguan.nPoint >= HM_Taoguan.nUseZJ then
		local bJ, bZ = true, true
		for _, v in ipairs(GetClientPlayer().GetBuffList()) do
			if v.dwID == 1660 and v.nLevel == 3 then
				bJ = false
			elseif v.dwID == 1661 and v.nLevel == 3 then
				bZ = false
			end
		end
		_HM_Taoguan.bHaveZJ = bJ == false and bZ == false
		if bJ and not _HM_Taoguan.UseBagItem("���ǹ�", HM_Taoguan.bPauseNoZJ) and HM_Taoguan.bPauseNoZJ then
			_HM_Taoguan.bEnable = false
		elseif bZ and not _HM_Taoguan.UseBagItem("����", HM_Taoguan.bPauseNoZJ) and HM_Taoguan.bPauseNoZJ then
			_HM_Taoguan.bEnable = false
		end
	elseif _HM_Taoguan.bEnable and HM_Taoguan.bUseJX and _HM_Taoguan.nPoint > 20 then
		if not HM_Force.HasBuff(1660) and not _HM_Taoguan.UseBagItem("��������") then
			_HM_Taoguan.UseBagItem("��������")
		end
		if not HM_Force.HasBuff(1661) and not _HM_Taoguan.UseBagItem("�������") then
			_HM_Taoguan.UseBagItem("���˽���")
		end
    end
end, 1000)
HM.RegisterEvent("NPC_ENTER_SCENE", _HM_Taoguan.OnNpcEnter)
HM.RegisterEvent("LOOT_ITEM", _HM_Taoguan.OnLootItem)
AppendCommand("�����չ�", _HM_Taoguan.Switch)

-- add to HM collector
HM.RegisterPanel("�����չ�����", 119, _L["Others"], _HM_Taoguan.PS)


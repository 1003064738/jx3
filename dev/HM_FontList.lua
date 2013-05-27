--
-- ��������������б�鿴
--

HM_FontList = {}

---------------------------------------------------------------------
-- ���غ����ͱ���
---------------------------------------------------------------------
local _HM_FontList = {
	nCur = 0,
	nMax = 255,
}

---------------------------------------------------------------------
-- ���ý���
---------------------------------------------------------------------
-- init panel
_HM_FontList.OnPanelActive = function(frame)
	local ui = HM.UI(frame)
	local txts = {}
	ui:Append("Text", { txt = "ϵͳ�����ȫ", x = 0, y = 0, font = 27 })
	for i = 1, 40 do
		local x = ((i - 1) % 8) * 62
		local y = math.floor((i - 1) / 8) * 55 + 30
		txts[i] = ui:Append("Text", { w = 62, h = 30, x = x, y = y, align = 1 })
	end
	local btn1 = ui:Append("WndButton", { txt = "��һҳ", x = 0, y = 320 })
	local nX, _ = btn1:Pos_()
	local btn2 = ui:Append("WndButton", { txt = "��һҳ", x = nX, y = 320 })
	btn1:Click(function()
		_HM_FontList.nCur = _HM_FontList.nCur - #txts
		if _HM_FontList.nCur <= 0 then
			_HM_FontList.nCur = 0
			btn1:Enable(false)
		end
		btn2:Enable(true)
		for k, v in ipairs(txts) do
			local i = _HM_FontList.nCur + k - 1
			if i > _HM_FontList.nMax then
				txts[k]:Text("")
			else
				txts[k]:Text("����" .. i)
				txts[k]:Font(i)
			end
		end
	end):Click()
	btn2:Click(function()
		_HM_FontList.nCur = _HM_FontList.nCur + #txts
		if (_HM_FontList.nCur + #txts) >= _HM_FontList.nMax then
			btn2:Enable(false)
		end
		btn1:Enable(true)
		for k, v in ipairs(txts) do
			local i = _HM_FontList.nCur + k - 1
			if i > _HM_FontList.nMax then
				txts[k]:Text("")
			else
				txts[k]:Text("����" .. i)
				txts[k]:Font(i)
			end
		end
	end)
end

---------------------------------------------------------------------
-- ע���¼�����ʼ��
---------------------------------------------------------------------
-- add to HM panel
HM.RegisterPanel("ϵͳ�����ȫ", 1925, "����", _HM_FontList)

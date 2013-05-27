--
-- ���������ͼ���б�鿴
--

HM_IconList = {}

---------------------------------------------------------------------
-- ���غ����ͱ���
---------------------------------------------------------------------
local _HM_IconList = {
	nCur = 0,
	nMax = 3481,
}

---------------------------------------------------------------------
-- ���ý���
---------------------------------------------------------------------
-- init panel
_HM_IconList.OnPanelActive = function(frame)
	local ui = HM.UI(frame)
	local imgs, txts = {}, {}
	ui:Append("Text", { txt = "ϵͳͼ���ȫ", x = 0, y = 0, font = 27 })
	for i = 1, 40 do
		local x = ((i - 1) % 10) * 50
		local y = math.floor((i - 1) / 10) * 70 + 40
		imgs[i] = ui:Append("Image", { w = 48, h = 48, x = x, y = y})
		txts[i] = ui:Append("Text", { w = 48, h = 20, x = x, y = y + 48, align = 1 })
	end
	local btn1 = ui:Append("WndButton", { txt = "��һҳ", x = 0, y = 320 })
	local nX, _ = btn1:Pos_()
	local btn2 = ui:Append("WndButton", { txt = "��һҳ", x = nX, y = 320 })
	btn1:Click(function()
		_HM_IconList.nCur = _HM_IconList.nCur - #imgs
		if _HM_IconList.nCur <= 0 then
			_HM_IconList.nCur = 0
			btn1:Enable(false)
		end
		btn2:Enable(true)
		for k, v in ipairs(imgs) do
			local i = _HM_IconList.nCur + k - 1
			if i > _HM_IconList.nMax then
				break
			end
			imgs[k]:Icon(i)
			txts[k]:Text(tostring(i))
		end
	end):Click()
	btn2:Click(function()
		_HM_IconList.nCur = _HM_IconList.nCur + #imgs
		if (_HM_IconList.nCur + #imgs) >= _HM_IconList.nMax then
			btn2:Enable(false)
		end
		btn1:Enable(true)
		for k, v in ipairs(imgs) do
			local i = _HM_IconList.nCur + k - 1
			if i > _HM_IconList.nMax then
				break
			end
			imgs[k]:Icon(i)
			txts[k]:Text(tostring(i))
		end
	end)
end

---------------------------------------------------------------------
-- ע���¼�����ʼ��
---------------------------------------------------------------------
-- add to HM panel
HM.RegisterPanel("ϵͳͼ���ȫ", 591, "����", _HM_IconList)
HM.bDevelopper = true

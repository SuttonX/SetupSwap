-- Geometry checks run the actual UI builder/layout against a small WoW UI mock.
local objects={}
local function object(kind,parent)
    local o={kind=kind,parent=parent,w=0,h=0,text='',fontSize=12,scripts={},shown=true}
    objects[#objects+1]=o
    function o:SetScript(key,fn) self.scripts[key]=fn end
    function o:GetScript(key) return self.scripts[key] end
    function o:SetSize(w,h)
        local changed=self.w~=w or self.h~=h;self.w=w;self.h=h
        if changed and self.scripts.OnSizeChanged then self.scripts.OnSizeChanged(self,w,h) end
    end
    function o:SetWidth(w) self.w=w end
    function o:SetHeight(h) self.h=h end
    function o:GetWidth() return self.w end
    function o:GetHeight() return self.h end
    function o:SetPoint(point,relative,rel,x,y)
        if type(relative)~='table' then relative=self.parent;rel=point;x=0;y=0 end
        self.anchor={point=point,relative=relative,rel=rel,x=x or 0,y=y or 0}
    end
    function o:ClearAllPoints() self.anchor=nil end
    function o:SetText(text) self.text=text;if self.fs then self.fs.text=text end end
    function o:GetText() return self.text end
    function o:GetFont() return 'mock',self.fontSize,'' end
    function o:SetFont(_,size) self.fontSize=size end
    function o:SetWordWrap(value) self.wrap=value end
    function o:GetStringWidth()
        local n=0;for line in (self.text..'\n'):gmatch('(.-)\n') do n=math.max(n,#line) end
        return n*self.fontSize*.55
    end
    function o:GetStringHeight()
        local lines=0
        for line in (self.text..'\n'):gmatch('(.-)\n') do
            lines=lines+math.max(1,math.ceil(#line*self.fontSize*.55/math.max(1,self.w)))
        end
        return lines*self.fontSize*1.2
    end
    function o:CreateFontString() return object('FontString',self) end
    function o:Hide() self.shown=false end
    function o:Show() self.shown=true end
    function o:IsShown() return self.shown end
    function o:SetChecked(value) self.checked=value end
    function o:GetChecked() return self.checked end
    for _,method in ipairs({'SetJustifyH','SetBackdrop','SetMovable','EnableMouse','RegisterForDrag',
        'SetClampedToScreen','SetFrameStrata','RegisterEvent','SetAutoFocus','ClearFocus','SetTextColor','SetAlpha','Disable','Enable'}) do
        o[method]=function() end
    end
    if kind=='Button' then
        o.fs=object('FontString',o)
        function o:GetFontString() return self.fs end
    end
    return o
end
function CreateFrame(kind,_,parent) return object(kind,parent) end
UIParent=object('Frame');UIParent:SetSize(1920,1080)
UISpecialFrames={};StaticPopupDialogs={};tinsert=table.insert
function GetAddOnMetadata() return '1.2.3-test4' end
function IsAddOnLoadOnDemand() return false end
function FauxScrollFrame_Update(frame,total,visible,height)
    frame.total=total;frame.visible=visible;frame.rowHeight=height
    frame.offset=math.min(frame.offset or 0,math.max(0,total-visible))
end
function FauxScrollFrame_GetOffset(frame) return frame.offset or 0 end
SetupSwap={name='SetupSwap',db={profiles={desktop={addons={}}},active='desktop'}}
local AM=SetupSwap
function AM:CharacterKey() return 'Ashbringer/Druid' end
function AM:EffectiveState(profile,entry) return profile.addons[entry.name]==true end
function AM:Inventory()
    local entries,byName={},{}
    for i=1,35 do
        local e={name='Addon'..i,title='Addon '..i..' with a longer descriptive title',enabled=true,dependencies={}}
        entries[i]=e;byName[e.name]=e
    end
    return entries,byName
end
dofile('SetupSwap/UI.lua')
AM:BuildUI()
local f=AM.ui
f.selected='desktop';f.draft={addons={},customize=true,captureSettings=true}
local checks=0
local function check(ok,message) assert(ok,message);checks=checks+1 end
local function box(o)
    local a=assert(o.anchor,'Missing anchor')
    local x,y=a.x,-a.y
    if a.relative~=f then
        local p=box(a.relative);x=x+p.x;y=y+p.y
    end
    return {x=x,y=y,w=o.w,h=o.h}
end
local function contains(o)
    local r=box(o)
    check(r.x>=-1e-6 and r.y>=-1e-6 and r.x+r.w<=f.w+1e-6 and r.y+r.h<=f.h+1e-6,
        'Control outside container: '..o.text)
end
local function noOverlap(a,b)
    local x,y=box(a),box(b)
    check(x.x+x.w<=y.x+1e-6 or y.x+y.w<=x.x+1e-6 or x.y+x.h<=y.y+1e-6 or y.y+y.h<=x.y+1e-6,
        'Overlapping controls: '..a.text..' / '..b.text)
end
local function validate()
    AM:RefreshUI()
    local ordered={f.heading,f.steps[1],f.steps[2],f.status,f.profileLabel,f.profileControls,
        f.selectionHint,f.addonWarning,f.includeSettings,f.characterOnly,f.scope,
        f.captureControls,f.legend,f.scroll,f.footerControls,f.guidance}
    for i,o in ipairs(ordered) do contains(o);if i>1 then noOverlap(ordered[i-1],o) end end
    for _,o in ipairs({f.profileName,f.saveProfile,f.selectProfile,f.deleteProfile,f.includeLabel,
        f.characterLabel,f.barsOnly,f.saveSettings,f.useCurrent,f.selectAll,f.deselectAll,f.switchProfile}) do contains(o) end
    noOverlap(f.includeSettings,f.includeLabel);noOverlap(f.characterOnly,f.characterLabel)
    noOverlap(f.barsOnly,f.saveSettings);noOverlap(f.saveProfile,f.selectProfile)
    check(f.barsOnly.fs:GetStringWidth()<=f.barsOnly.w,'Macro button label clipped')
    check(f.visibleRows>=3 and f.visibleRows<=#f.rows,'Not enough visible addon rows')
    local last=f.rows[f.visibleRows]
    contains(last)
    noOverlap(last,f.footerControls)
    noOverlap(last.title,last.folder)
    for i=f.visibleRows+1,#f.rows do check(not f.rows[i].shown,'Invisible row escaped list') end
    check(f.scroll.visible==f.visibleRows and f.scroll.rowHeight==f.rowHeight,'Scrollbar uses stale fixed row sizing')
    f.scroll.offset=35-f.visibleRows;AM:RefreshRows()
    check(f.rows[f.visibleRows].entry.name=='Addon35','Last addon cannot be reached')
    f.scroll.offset=0;AM:RefreshRows()
end
for _,size in ipairs({{1280,720},{1920,1080},{3840,2160},{1024,768},{800,600}}) do
    UIParent:SetSize(size[1],size[2]);AM:FitUIToScreen();validate()
    check(f.w<=UIParent.w*.90+1e-6 and f.h<=UIParent.h*.90+1e-6,'Window does not fit screen')
end
for _,size in ipairs({{600,700},{900,650},{500,600}}) do
    f:SetSize(size[1],size[2]);validate()
end
f.draft.customize=false;validate()
local clicked=0
AM.RequestActionBarsSave=function() clicked=clicked+1 end
f.barsOnly.scripts.OnClick()
check(clicked==1,'Bars/macros button lost its handler')
check(f.heading.text=='SetupSwap v1.2.3','Title uses the TOC version without the test suffix')
check(f.barsOnly.text=='Save Action Bars / Macros' and f.saveSettings.text=='Save Addon Settings + Positions','Save buttons have distinct labels')
-- ElvUI stays optional; apply its native handlers only after its engine is ready.
function IsAddOnLoaded() return false end
dofile('SetupSwap/ElvUISkin.lua')
check(not AM:ApplyElvUISkin(f) and not f.elvUISkinned,'Default skin retained with ElvUI disabled')
function IsAddOnLoaded() return true end
ElvUI={{GetModule=function() return {} end}}
check(not AM:ApplyElvUISkin(f),'ElvUI skin waits for the engine to be ready')
local calls=0
local S={}
for _,method in ipairs({'HandleButton','HandleEditBox','HandleCheckBox','HandleCloseButton','HandleScrollBar'}) do
    S[method]=function(_,control)
        assert(control,'Skin received a missing control');calls=calls+1
        if method=='HandleCloseButton' then control.Texture=object('Texture',control) end
        if method=='HandleCheckBox' then
            control:SetSize(16,16)
            control.backdrop=object('Frame',control)
        end
    end
end
ElvUI={{media={},private={},db={general={}},GetModule=function() return S end}}
f.scroll.ScrollBar=object('Slider',f.scroll)
function f:StripTextures() end
function f:SetTemplate(template) self.skinTemplate=template end
function f.profileName:StripTextures() end
check(AM:ApplyElvUISkin(f) and f.skinTemplate=='Transparent','ElvUI uses its transparent frame template')
check(calls==34,'All options buttons, editbox, checkboxes and close button are skinned')
validate()
local before=calls
check(not AM:ApplyElvUISkin(f) and calls==before,'Repeated opens do not duplicate skin hooks')
f:SetSize(600,700);validate()
check(f.includeSettings.w==f.rows[1].check.w and f.includeSettings.w~=16,'Relative checkbox sizes survive native skin handlers and resizing')
check(math.abs(f.close.Texture.w-f.close.w*.45)<.000001,'ElvUI close icon scales with its button')
check(math.abs(f.scroll.ScrollBar.w-f.rowHeight/2.2*1.5)<.000001,'ElvUI scrollbar scales with row sizing')
print(checks..' responsive UI geometry checks passed')

-- Scratch geometry output supports an internal rendered layout inspection.
UIParent:SetSize(1024,768);AM:FitUIToScreen();AM:RefreshUI()
local out=assert(io.open('../ui-layout-geometry.json','w'))
local function quoted(s) return '"'..s:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n')..'"' end
out:write('{"width":'..f.w..',"height":'..f.h..',"objects":[')
local first=true
local function emit(o,kind)
    local r=box(o);if not first then out:write(',') end;first=false
    out:write(string.format('{"x":%.3f,"y":%.3f,"w":%.3f,"h":%.3f,"font":%.3f,"kind":%s,"text":%s}',r.x,r.y,r.w,r.h,o.fs and o.fs.fontSize or o.fontSize,quoted(kind),quoted(o.text)))
end
for _,o in ipairs({f.heading,f.steps[1],f.steps[2],f.status,f.profileLabel,f.selectionHint,f.addonWarning,f.includeLabel,f.characterLabel,f.scope,f.legend,f.guidance}) do emit(o,'text') end
for _,o in ipairs({f.saveProfile,f.selectProfile,f.deleteProfile,f.barsOnly,f.saveSettings,f.useCurrent,f.selectAll,f.deselectAll,f.switchProfile}) do emit(o,'button') end
f.profileName.text='desktop';emit(f.profileName,'edit')
emit(f.includeSettings,'check');emit(f.characterOnly,'check');emit(f.scroll,'list')
for i=1,f.visibleRows do local row=f.rows[i];emit(row.check,'check');emit(row.title,'rowtext');emit(row.folder,'rowtext') end
out:write(']}');out:close()

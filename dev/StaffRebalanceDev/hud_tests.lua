-- SPDX-License-Identifier: MPL-2.0
-- Native UMG presentation mock: owns only fabricated UI; does not mock combat.
local file=assert(arg[1],"StaffReserveHud.lua path")
local all,seq={},100
local function make(path,classPath,outer)
    seq=seq+1
    local o={_path=path,_class=classPath,_outer=outer,_address=seq,
        _visible=0,_opacity=1,_children={}}
    function o:IsValid() return not self.destroyed end
    function o:GetFullName() return "Object " .. self._path end
    function o:GetAddress() return self._address end
    function o:GetOuter() return self._outer end
    function o:GetParent() return self._parent end
    function o:GetRenderOpacity() return self._opacity end
    function o:SetRenderOpacity(v) self._opacity=v end
    function o:SetVisibility(v) self._visible=v end
    local c={GetFullName=function() return "Class "..classPath end,
        GetFName=function() return {ToString=function() return classPath:match("([^.]+)$") end} end}
    function o:GetClass() return c end
    function o:AddChildToCanvas(child)
        assert(child._parent==nil)
        child._parent=self;self._children[#self._children+1]=child
        local slot={Parent=self,Content=child,
            GetFullName=function() return "CanvasPanelSlot /Script/UMG.CanvasPanelSlot" end,
            GetAddress=function() return 777 end,
            IsValid=function() return true end,
            GetClass=function() return {GetFullName=function() return "Class /Script/UMG.CanvasPanelSlot" end} end,
            SetAutoSize=function() end,SetAnchors=function() end,SetAlignment=function() end,
            SetPosition=function() end,SetSize=function() end}
        return slot
    end
    function o:RemoveChild(child)
        for i,v in ipairs(self._children) do
            if v==child then
                table.remove(self._children,i);child._parent=nil;return true
            end
        end
        return false
    end
    function o:SetColorAndOpacity(v) self._color=v end
    function o:SetText(v) self._text=v end
    function o:SetBrush(v) self.Brush=v end
    all[path]=o
    return o
end
local classNames={"CanvasPanel","TextBlock","Image"}
local classes={}
for _,kind in ipairs(classNames) do
    classes["/Script/UMG."..kind]={
        IsValid=function() return true end,type=function() return "UClass" end,
        GetFullName=function() return "Class /Script/UMG."..kind end}
end
local pawn=make("World.Hilda","/Game/hilda_BP_C")
pawn.GetClass=function()
    return {GetFullName=function() return "BlueprintGeneratedClass /Game/hilda_BP_C" end,
        GetFName=function() return {ToString=function() return "hilda_BP_C" end} end}
end
local current,cap=3,3
local function ownerId() return pawn:GetFullName().."@"..tostring(pawn:GetAddress()) end
local function createHost(suffix, foreign)
    local hud=make("World."..suffix,"/Game/HUDMainUMG_BP_C")
    local tree=make(hud._path..".WidgetTree","/Script/UMG.WidgetTree",hud)
    local left=make(tree._path..".LeftBottom_Panel","/Script/UMG.CanvasPanel",tree)
    local status=make(tree._path..".HUDStatusBarUMG_BP","/Game/HUDStatusBarUMG_BP_C",tree)
    local ap=make(tree._path..".APBar","/Script/UMG.Image",tree)
    status._parent=left;left._children[#left._children+1]=status
    status.APBar=ap
    hud.WidgetTree=tree;hud.LeftBottom_Panel=left;hud.HUDStatusBarUMG_BP=status
    hud.inViewport=true
    hud.IsInViewport=function(self) return self.inViewport end
    hud.GetOwningPlayerPawn=function() return foreign or pawn end
    return hud,left,ap
end
local hud0,left0,ap0=createHost("HUD0")
local hosts={hud0}
local loops,cancelled={},false
local e=setmetatable({}, {__index=_G})
e.StaticFindObject=function(path) return all[path] or classes[path] end
e.StaticConstructObject=function(c,tree,name)
    local nameText=tostring(name)
    local kind=c:GetFullName():match("([^.]+)$")
    local path=tree._path.."."..nameText
    local widget=make(path,"/Script/UMG."..kind,tree)
    if kind=="Image" then
        widget.Brush={ResourceObject=nil,ResourceName={ToString=function() return "None" end}}
    end
    return widget
end
e.FindAllOf=function() return hosts end
e.FName=function(s) return s end
e.FText=function(s) return s end
e.EObjectFlags={RF_Transient=1}
e.LoopInGameThreadWithDelay=function(ms,cb)
    assert(ms==100)
    loops[#loops+1]=cb
    return 24
end
e.CancelDelayedAction=function(handle)
    assert(handle==24);cancelled=true;return true
end
local callback=assert(loadfile(file,"t",e))()
local events={}
local view=callback(function() return current,cap,ownerId() end,
    function(ev,detail) events[#events+1]=ev.." "..detail end)
assert(view.start())
local function frame(n)
    for _=1,(n or 1) do loops[1]() end
end
frame()
assert(#left0._children==2,"status+one owned canvas")
local root=left0._children[2]
assert(root._visible==3 and #root._children==7)
for _,widget in ipairs(root._children) do assert(widget._visible==3) end
local fills={root._children[4],root._children[6],root._children[7]}
-- TextBlock + Bg1/Fill1 + Bg2/Fill2 + Bg3/Fill3.
fills={root._children[3],root._children[5],root._children[7]}
for _,fill in ipairs(fills) do assert(fill._color and fill._color.A>0.9) end
current=1;view.changed(3,1);frame()
assert(fills[1]._color.A>0.9 and fills[2]._color.A<0.2 and fills[3]._color.A<0.2)
view.changed(1,1);frame()
local values=0
for _,line in ipairs(events) do if line:match("^VALUE") then values=values+1 end end
assert(values==2,"no phantom update at cap/unchanged reserve")
ap0:SetRenderOpacity(0.2);frame()
assert(root:GetRenderOpacity()==0.2,"read-only AP fade follows")
assert(ap0:GetRenderOpacity()==0.2)
hud0.inViewport=false
frame()
assert(#left0._children==1,"old owned root removed, native status preserved")
local hud1,left1=createHost("HUD1")
hosts={hud1};frame(10)
assert(#left1._children==2,"late rebinding creates one own canvas")
frame(12);assert(#left1._children==2,"no duplicate root")
view.stop()
assert(cancelled and #left1._children==1,"F7 cleanup detaches own root")
frame();assert(#left1._children==1,"stale callback inert")
print("PASS: native UMG reserve HUD construction, update, fade, owner rebind and cleanup")

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
    function o:GetVisibility() return self._visible end
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
            SetAutoSize=function() end,SetAnchors=function(_,v) child.anchors=v end,SetAlignment=function(_,v) child.alignment=v end,
            SetPosition=function(_,v) child.position=v end,SetSize=function(_,v) child.size=v end}
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
    function o:SetBrushFromTexture(texture,matchSize)
        assert(matchSize==false and texture:IsValid())
        self.Brush.ResourceObject=texture
    end
    function o:SetBrushResourceObject(texture)
        assert(texture==nil)
        self.Brush.ResourceObject=texture
    end
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
local current,cap=10,10
local inputMode,menuVisibility=0,3
local element,elementError="astral",false
local hand=1
pawn.GetPropertyValue=function(_,key)
    assert(key=="Magic_Elemental")
    if elementError then error("candidate field unavailable") end
    return element
end
local function ownerId() return pawn:GetFullName().."@"..tostring(pawn:GetAddress()) end
local function createHost(suffix, foreign)
    local hud=make("World."..suffix,"/Game/HUDMainUMG_BP_C")
    local tree=make(hud._path..".WidgetTree","/Script/UMG.WidgetTree",hud)
    local left=make(tree._path..".LeftBottom_Panel","/Script/UMG.CanvasPanel",tree)
    local status=make(tree._path..".HUDStatusBarUMG_BP","/Game/HUDStatusBarUMG_BP_C",tree)
    local ap=make(tree._path..".APBar","/Script/UMG.Image",tree)
    status._parent=left;left._children[#left._children+1]=status
    status.APBar=ap
    local main=make(tree._path..".Main_Panel","/Script/UMG.CanvasPanel",tree)
    local menuOwner=make(tree._path..".HUD_Panel","/Script/UMG.CanvasPanel",tree)
    menuOwner.GetVisibility=function() return menuVisibility end
    left._parent=menuOwner
    tree.RootWidget=main
    setmetatable(hud,{__index=function(_,key)
        assert(key~="Main_Panel","Main_Panel has no direct HUD alias")
    end})
    hud.WidgetTree=tree;hud.LeftBottom_Panel=left;hud.HUDStatusBarUMG_BP=status
    hud.inViewport=true
    hud.IsInViewport=function(self) return self.inViewport end
    hud.GetOwningPlayerPawn=function() return foreign or pawn end
    return hud,main,ap
end
local hud0,left0,ap0=createHost("HUD0")
local hosts={hud0}
local loops,cancelled={},false
local e=setmetatable({}, {__index=_G})
local first,second=4,2
local global={IsValid=function() return true end,
    GetFullName=function() return "GameGlobal /Script/Genesis.Default__GameGlobal" end,
    GetInHandWeaponType=function() return hand end,
    GetInputMode=function(_,ui,ignore)
        assert(ui==true and ignore==false)
        return inputMode
    end,
    GetInUseWeaponType=function(_,_,index)
        if index==0 then return first end
        return second
    end}
all["/Script/Genesis.Default__GameGlobal"]=global
local library=make("/Script/Engine.Default__KismetRenderingLibrary","/Script/Engine.KismetRenderingLibrary")
local importerPath="/Script/Engine.KismetRenderingLibrary:ImportFileAsTexture2D"
local imports,missing={},{}
local dimensions={
    reserve_backdrop={680,48},reserve_cap_left={24,20},reserve_cap_right={24,20},
    reserve_slot_empty={56,24},reserve_slot_fill={64,40},reserve_slot_light={64,40},
}
all[importerPath]=setmetatable({
    IsValid=function() return true end,type=function() return "UFunction" end,
    GetFullName=function() return "Function "..importerPath end,
},{
    __call=function(_,context,hud,filename)
        assert(context==library and hud==hosts[1])
        local name=assert(filename:match("[/\\]Scripts[/\\]ReserveArt[/\\](reserve_.+)%.png$"))
        assert(io.open(filename,"rb")):close()
        local size=assert(dimensions[name])
        imports[name]=(imports[name] or 0)+1
        if missing[name] then return nil end
        local texture=make("Transient."..name..imports[name],"/Script/Engine.Texture2D")
        texture.HasAnyFlags=function(_,flag) return flag==1 end
        texture.Blueprint_GetSizeX=function() return size[1] end
        texture.Blueprint_GetSizeY=function() return size[2] end
        return texture
    end,
})
e.StaticFindObject=function(path) return all[path] or classes[path] end
e.StaticConstructObject=function(c,tree,name)
    local nameText=tostring(name)
    local kind=c:GetFullName():match("([^.]+)$")
    local path=tree._path.."."..nameText
    local widget=make(path,"/Script/UMG."..kind,tree)
    if kind=="Image" then
        widget.Brush={ResourceObject=nil,DrawAs=3}
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
local function observations()
    local n=0
    for _,line in ipairs(events) do if line:match("^ELEMENT_OBS ") then n=n+1 end end
    return n
end
frame()
assert(observations()==1 and events[2]:find('value="astral"',1,true))
frame(3);assert(observations()==1,"no unchanged per-tick element logs")
assert(#left0._children==1,"one owned canvas under main")
local root=left0._children[1]
assert(root._visible==3 and #root._children==33)
assert(root.position.Y==-25 and root.size.X==255 and root.size.Y==24)
assert(root.anchors.Minimum.X==0.5 and root.anchors.Maximum.X==0.5)
assert(root.alignment.X==0.5 and root.position.X==0 and root.position.Y<0)
local children={table.unpack(root._children)}
for _,widget in ipairs(children) do
    assert(widget._visible==3 and widget._class=="/Script/UMG.Image")
    assert(widget.position.X>=0 and widget.position.X+widget.size.X<=root.size.X)
    assert(widget.position.Y>=0 and widget.position.Y+widget.size.Y<=root.size.Y)
    assert(widget.Brush.ResourceObject and widget.Brush.DrawAs==3)
end
local fills,lights={},{}
for name in pairs(dimensions) do assert(imports[name]==1) end
for i=1,10 do
    local well=children[3+i]
    fills[i]=children[13+i]
    lights[i]=children[23+i]
    assert(well.Brush.ResourceObject==children[4].Brush.ResourceObject)
    assert(fills[i].Brush.ResourceObject==fills[1].Brush.ResourceObject)
    assert(well.position.X==9+(i-1)*24 and well.size.X==21 and well.size.Y==10)
    assert(fills[i].position.X+1.5==well.position.X)
    assert(lights[i].position.X==fills[i].position.X and lights[i].position.Y==fills[i].position.Y)
    assert(lights[i].size.X==fills[i].size.X and lights[i].size.Y==fills[i].size.Y)
    assert(lights[i].Brush.ResourceObject==lights[1].Brush.ResourceObject)
end
for _,fill in ipairs(fills) do assert(fill._color and fill._color.A>0.9) end
local astralColor=fills[1]._color
element="fire";frame()
assert(observations()==2 and fills[1]._color.R==1 and fills[1]._color.G==0.15)
assert(fills[1]._color~=astralColor and current==10,"element change updates without reserve change")
elementError=true;frame(3)
assert(observations()==3 and root._visible==3,"read failure stays diagnostic only")
local neutral=fills[1]._color
assert(neutral.R==0.84 and neutral.G==0.93)
elementError=false;element=nil;frame(3)
assert(observations()==4,"unsupported type logs once")
element="fire";frame()
assert(observations()==5)
current=1;view.changed(10,1);frame()
for i,fill in ipairs(fills) do assert((fill._color.A>0.9)==(i==1)) end
view.changed(1,1);frame()
local values=0
for _,line in ipairs(events) do if line:match("^VALUE") then values=values+1 end end
assert(values==5,"only reserve or resolved color changes redraw")
local emptyColor=fills[2]._color
for _,case in ipairs({
    {"astral",0.012,0.51,1},{"fire",1,0.15,0.008},
    {"ice",0.035,0.90,0.67},{"thunder",1,0.72,0.013},
}) do
    element=case[1];frame()
    local c=fills[1]._color
    assert(c.R==case[2] and c.G==case[3] and c.B==case[4] and c.A==0.98)
    local core=lights[1]._color
    assert(core.R==1 and core.G==1 and core.B==1 and core.A==1)
    assert(lights[2]._color.A==0)
    assert(fills[2]._color.R==emptyColor.R and fills[2]._color.A==emptyColor.A)
    for i=1,13 do
        local tint=children[i]._color
        assert(tint.R==1 and tint.G==1 and tint.B==1 and tint.A==1)
    end
end
element="Fire";frame()
assert(fills[1]._color==neutral,"unknown case must not guess an element")
ap0:SetRenderOpacity(0.2);frame()
assert(root:GetRenderOpacity()==0.2,"read-only AP fade follows")
assert(ap0:GetRenderOpacity()==0.2)
-- Main_Panel remains visible while the native HUD branch is hidden by menus.
for _,visibility in ipairs({1,2}) do
    menuVisibility=visibility;frame()
    assert(root._visible==1 and current==1 and #left0._children==1)
end
menuVisibility=3;inputMode=1;frame()
assert(root._visible==1,"UI input mode hides even before native owner hides")
inputMode=0;frame()
assert(root._visible==3 and root:GetRenderOpacity()==0.2,"scene restores own HUD at CombatHUD opacity")
menuVisibility=nil;frame()
assert(root._visible==1,"unknown menu owner visibility fails closed")
menuVisibility=3;frame()
first,second=2,7;frame()
assert(root._visible==1 and current==1,"staff absent hides without reserve reset")
first,second=2,4;frame()
assert(root._visible==3,"staff in second slot while melee selected")
first=nil;frame()
assert(root._visible==1,"unknown slot fails closed")
first,second=4,7;frame()
assert(root._visible==3 and #left0._children==1,"re-equip reuses existing root")
current=0;frame()
for i,fill in ipairs(fills) do assert(fill._color.A==0 and lights[i]._color.A==0) end
current=4;frame()
for i,fill in ipairs(fills) do
    assert(fill._color.A==(i<=4 and 0.98 or 0) and lights[i]._color.A==(i<=4 and 1 or 0))
end
current=10;frame()
for i,fill in ipairs(fills) do assert(fill._color.A>0.9 and lights[i]._color.A==1) end
first=6;frame()
assert(root._visible==1,"COUNT_MAX is not an equipped weapon")
first=4;frame()
for i=1,20 do element="unknown_"..i;frame() end
assert(observations()==16,"bounded element change diagnostics")
element="fire";frame()
assert(observations()==16 and fills[1]._color.G==0.15,"color still updates after trace limit")
hud0.inViewport=false
frame()
assert(#left0._children==0,"old owned root removed")
for _,widget in ipairs(children) do assert(widget.Brush.ResourceObject==nil) end
local hud1,left1=createHost("HUD1")
hosts={hud1};frame(10)
assert(#left1._children==1,"late rebinding creates one own canvas")
frame(12);assert(#left1._children==1,"no duplicate root")
for name in pairs(dimensions) do assert(imports[name]==2,"only one import per mount") end
local rebound={table.unpack(left1._children[1]._children)}
view.stop()
assert(cancelled and #left1._children==0,"F7 cleanup detaches own root")
for _,widget in ipairs(rebound) do assert(widget.Brush.ResourceObject==nil) end
frame();assert(#left1._children==0,"stale callback inert")
local hud2,left2=createHost("HUD2")
hosts={hud2}
missing.reserve_cap_right=true
local failureEvents={}
local failed=callback(function() return current,cap,ownerId() end,
    function(ev,detail) failureEvents[#failureEvents+1]=ev.." "..detail end)
assert(failed.start())
for _=1,12 do loops[2]() end
assert(#left2._children==0 and imports.reserve_cap_right==3,"partial art failure detaches without retry")
assert(failureEvents[1]:find("reserve_art_import_failed:reserve_cap_right",1,true))
for path,widget in pairs(all) do
    if path:find("HUD2",1,true) and widget.Brush then assert(widget.Brush.ResourceObject==nil) end
end
print("PASS: native UMG reserve HUD construction, update, fade, owner rebind and cleanup")

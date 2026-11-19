-- SPDX-License-Identifier: MPL-2.0
-- Dev-only UMG overlay: no combat mutations, no CombatHUD writes, no input focus.
local source=debug.getinfo(1,"S").source
local artDirectory=source:match("^@(.+[/\\])StaffReserveHud%.lua$")
local importerPath="/Script/Engine.KismetRenderingLibrary:ImportFileAsTexture2D"
local backdrop={"reserve_backdrop",340,24}
local capLeft={"reserve_cap_left",12,10}
local capRight={"reserve_cap_right",12,10}
local empty={"reserve_slot_empty",28,12}
local charged={"reserve_slot_fill",32,20}
local light={"reserve_slot_light",32,20}
local widthScale=0.75
local white={R=1,G=1,B=1,A=1}
local transparent={R=1,G=1,B=1,A=0}

return function(snapshot, log)
    local neutral={R=0.84,G=0.93,B=1,A=0.98}
    local presets={
        astral={R=0.012,G=0.51,B=1,A=0.98},
        fire={R=1,G=0.15,B=0.008,A=0.98},
        ice={R=0.035,G=0.90,B=0.67,A=0.98},
        thunder={R=1,G=0.72,B=0.013,A=0.98},
    }
    local active,disabled,worker,tick,generation=false,false,nil,0,0
    local owned,dirty=nil,true
    local function valid(v) return v~=nil and v:IsValid() end
    local function fullPath(v) return assert(v:GetFullName():match("^[^ ]+ (.+)$")) end
    local function cls(v) return valid(v) and fullPath(v:GetClass()) end
    local function same(a,b) return valid(a) and valid(b) and a:GetAddress()==b:GetAddress() end
    local function ref(v)
        return {path=fullPath(v),address=v:GetAddress(),class=cls(v)}
    end
    local function resolve(r)
        if not r then return nil end
        local obj=StaticFindObject(r.path)
        if not valid(obj) or obj:GetAddress()~=r.address or cls(obj)~=r.class then return nil end
        return obj
    end
    local function detach(reason)
        local state=owned
        owned=nil
        if not state then return end
        local failures=0
        for i=#state.children,1,-1 do
            local w,parent,tree=resolve(state.children[i]),resolve(state.root),resolve(state.tree)
            if w and same(w:GetOuter(),tree) then
                local ok=pcall(function()
                    w:SetVisibility(1)
                    if same(w:GetParent(),parent) then
                        assert(parent:RemoveChild(w)==true and not valid(w:GetParent()))
                    end
                end)
                if not ok then failures=failures+1 end
                local cleared=pcall(function()
                    if valid(w.Brush.ResourceObject) then
                        w:SetBrushResourceObject(nil)
                        assert(not valid(w.Brush.ResourceObject),"brush_resource_not_cleared")
                    end
                end)
                if not cleared then failures=failures+1 end
            end
        end
        local root,left=resolve(state.root),resolve(state.left)
        if root and left and same(root:GetParent(),left) then
            local ok=pcall(function()
                root:SetVisibility(1)
                assert(left:RemoveChild(root)==true and not valid(root:GetParent()))
            end)
            if not ok then failures=failures+1 end
        end
        log("DETACH","reason="..reason.." failures="..failures)
        if failures>0 then disabled=true end
    end
    local function create(kind,tree,name,record)
        local classObj=StaticFindObject("/Script/UMG."..kind)
        assert(valid(classObj) and classObj:type()=="UClass","missing_widget_class:"..kind)
        assert(not valid(StaticFindObject(fullPath(tree).."."..name)),"widget_name_collision")
        local w=StaticConstructObject(classObj,tree,FName(name),EObjectFlags.RF_Transient)
        assert(valid(w) and cls(w)=="/Script/UMG."..kind
            and same(w:GetOuter(),tree),"widget_construct_failed:"..kind)
        w:SetVisibility(1)
        if record then record[#record+1]=ref(w) end
        return w
    end
    local function slot(parent,w,x,y,width,height,anchorX,anchorY,alignX,alignY)
        local s=parent:AddChildToCanvas(w)
        assert(valid(s) and cls(s)=="/Script/UMG.CanvasPanelSlot"
            and same(w:GetParent(),parent) and same(s.Parent,parent)
            and same(s.Content,w),"widget_slot_failed")
        s:SetAutoSize(false)
        s:SetAnchors({Minimum={X=anchorX,Y=anchorY},Maximum={X=anchorX,Y=anchorY}})
        s:SetAlignment({X=alignX,Y=alignY})
        s:SetPosition({X=x,Y=y});s:SetSize({X=width,Y=height})
    end
    -- Read current host state each refresh; diagnostic limits never freeze color.
    local function elementColor(state,pawn)
        local probe=state.elementProbe
        if not probe then
            probe={remaining=16}
            state.elementProbe=probe
        end
        local rawType="unavailable"
        local ok,value=pcall(function()
            local raw=pawn:GetPropertyValue("Magic_Elemental")
            rawType=type(raw)
            if rawType=="string" then return raw end
            if rawType=="userdata" then return raw:ToString() end
            return "<unsupported_type>"
        end)
        if not ok or type(value)~="string" then value="<read_failed>" end
        local color=presets[value] or neutral
        if probe.remaining==0 then return color end
        value=value:sub(1,32)
        local key=rawType..":"..value
        if key==probe.last then return color end
        probe.last=key
        probe.remaining=probe.remaining-1
        local contextOk,hand,first,second=pcall(function()
            local global=StaticFindObject("/Script/Genesis.Default__GameGlobal")
            return global:GetInHandWeaponType(pawn),
                global:GetInUseWeaponType(pawn,0),global:GetInUseWeaponType(pawn,1)
        end)
        log("ELEMENT_OBS",("generation=%d value=%q lua_type=%s hand=%s slots=%s,%s remaining=%d")
            :format(generation,value,rawType,contextOk and tostring(hand) or "?",
                contextOk and tostring(first) or "?",contextOk and tostring(second) or "?",probe.remaining))
        return color
    end
    local function hudFor(owner)
        local chosen,count=nil,0
        for _,w in ipairs(FindAllOf("HUDMainUMG_BP_C") or {}) do
            if valid(w) and w:IsInViewport() then
                local pawn=w:GetOwningPlayerPawn()
                if valid(pawn) and pawn:GetClass():GetFName():ToString()=="hilda_BP_C"
                    and pawn:GetFullName().."@"..tostring(pawn:GetAddress())==owner then
                    chosen,count=w,count+1
                end
            end
        end
        if count~=1 then return end
        local tree=chosen.WidgetTree
        if not valid(tree) or cls(tree)~="/Script/UMG.WidgetTree"
            or not same(tree:GetOuter(),chosen) then return end
        local left,status=tree.RootWidget,chosen.HUDStatusBarUMG_BP
        if cls(left)~="/Script/UMG.CanvasPanel"
            or fullPath(left)~=fullPath(tree)..".Main_Panel"
            or not same(left:GetOuter(),tree) or valid(left:GetParent())
            or not valid(status) or not same(status:GetParent(),chosen.LeftBottom_Panel)
            or not valid(status.APBar) then return end
        return chosen,tree,left,status
    end
    local function mount(owner,capacity)
        local hud,tree,left,status=hudFor(owner)
        if not hud then return end
        assert(artDirectory,"reserve_art_module_path_unavailable")
        local import=StaticFindObject(importerPath)
        local library=StaticFindObject("/Script/Engine.Default__KismetRenderingLibrary")
        assert(valid(import) and import:type()=="UFunction" and import:GetFullName()=="Function "..importerPath
            and cls(library)=="/Script/Engine.KismetRenderingLibrary","reserve_art_importer_unavailable")
        generation=generation+1
        local name="StaffReserveHUD_"..generation
        local state={hud=ref(hud),tree=ref(tree),left=ref(left),
            status=ref(status),owner=owner,capacity=capacity,children={},fills={},lights={}}
        owned=state -- partial construction remains eligible for own-only cleanup
        local root=create("CanvasPanel",tree,name)
        state.root=ref(root)
        -- Fixed bottom-center anchor, independent of KBM/gamepad skill widgets.
        slot(left,root,0,-25,backdrop[2]*widthScale,backdrop[3],0.5,1,0.5,1)
        local textures={}
        local function box(suffix,x,y,art,color,displayHeight)
            local asset,width,height=table.unpack(art)
            local w=create("Image",tree,name..suffix,state.children)
            local texture=textures[asset]
            if not texture then
                texture=import(library,hud,artDirectory.."ReserveArt/"..asset..".png")
                assert(cls(texture)=="/Script/Engine.Texture2D"
                    and texture:HasAnyFlags(EObjectFlags.RF_Transient)
                    and texture:Blueprint_GetSizeX()==2*width
                    and texture:Blueprint_GetSizeY()==2*height,"reserve_art_import_failed:"..asset)
                textures[asset]=texture
            end
            w:SetBrushFromTexture(texture,false)
            assert(same(w.Brush.ResourceObject,texture) and w.Brush.DrawAs==3,"reserve_art_bind_failed:"..asset)
            w:SetColorAndOpacity(color)
            slot(root,w,x*widthScale,y,width*widthScale,displayHeight or height,0,0,0,0)
            return w
        end
        box("_Backdrop",0,0,backdrop,white)
        box("_LeftEnd",0,7,capLeft,white)
        box("_RightEnd",328,7,capRight,white)
        for i=1,capacity do
            local x=12+(i-1)*32
            box("_Bg"..i,x,7,empty,white,10)
        end
        -- Draw all halos above the wells. Only charged cells tint their brush.
        for i=1,capacity do
            local x=10+(i-1)*32
            local fill=box("_Fill"..i,x,2,charged,transparent)
            state.fills[i]=ref(fill)
        end
        for i=1,capacity do
            local x=10+(i-1)*32
            local core=box("_Light"..i,x,2,light,transparent)
            state.lights[i]=ref(core)
        end
        -- Constructed children started Hidden so partial configuration cannot flash.
        -- Reveal only fully configured, owned widgets; otherwise the root is empty.
        for _,childRef in ipairs(state.children) do
            local child=resolve(childRef)
            assert(child,"own_child_lost_during_attach")
            child:SetVisibility(3)
        end
        root:SetVisibility(3) -- SelfHitTestInvisible, no focus/input change
        dirty=true
        log("ATTACHED","slots="..capacity.." owned_widgets="..(#state.children+1))
    end
    local function refresh()
        local current,capacity,owner=snapshot()
        if math.type(current)~="integer" or math.type(capacity)~="integer"
            or capacity~=10 or current<0 or current>capacity
            or type(owner)~="string" or owner=="" then
            if owned then detach("inactive") end
            return
        end
        if owned then
            local state=owned
            local h,left,root=resolve(state.hud),resolve(state.left),resolve(state.root)
            local pawn=h and h:GetOwningPlayerPawn()
            if not h or not left or not root or not h:IsInViewport()
                or not valid(pawn) or pawn:GetFullName().."@"..tostring(pawn:GetAddress())~=owner
                or not same(root:GetParent(),left) or state.capacity~=capacity
                or state.owner~=owner then
                detach("owner_or_hud_changed")
            end
        end
        if not owned and (tick==1 or tick%10==0) then mount(owner,capacity) end
        local state=owned
        if not state then return end
        local root,status=resolve(state.root),resolve(state.status)
        assert(root and status and valid(status.APBar),"hud_widget_lost")
        local h=resolve(state.hud)
        local pawn=h and h:GetOwningPlayerPawn()
        local color=elementColor(state,pawn)
        local equipped=false
        local readOk,first,second,scene=pcall(function()
            local global=StaticFindObject("/Script/Genesis.Default__GameGlobal")
            assert(valid(global) and global:GetFullName()=="GameGlobal /Script/Genesis.Default__GameGlobal")
            local left=h.LeftBottom_Panel
            local menuOwner=valid(left) and left:GetParent()
            assert(valid(menuOwner),"native_menu_owner_unavailable")
            local visibility=menuOwner:GetVisibility()
            local sceneVisible=global:GetInputMode(true,false)==0
                and (visibility==0 or visibility==3 or visibility==4)
            return global:GetInUseWeaponType(pawn,0),global:GetInUseWeaponType(pawn,1),sceneVisible
        end)
        local function weaponType(v)
            return math.type(v)=="integer" and ((v>=0 and v<=5) or v==7)
        end
        if readOk and weaponType(first) and weaponType(second) then
            equipped=first==4 or second==4
        end
        local shown=equipped and scene==true
        root:SetVisibility(shown and 3 or 1)
        if shown~=state.shown then
            state.shown=shown
            log("VISIBILITY","shown="..tostring(shown))
        end
        local opacity=status.APBar:GetRenderOpacity() -- read-only CombatHUD fade reference
        assert(type(opacity)=="number" and opacity>=0 and opacity<=1,"invalid_ap_opacity")
        if math.abs(root:GetRenderOpacity()-opacity)>0.001 then root:SetRenderOpacity(opacity) end
        if dirty or current~=state.rendered or color~=state.color then
            for i=1,capacity do
                local fill=resolve(state.fills[i])
                local core=resolve(state.lights[i])
                assert(fill and core,"own_charge_images_lost")
                local lit=i<=current
                fill:SetColorAndOpacity(lit and color or transparent)
                core:SetColorAndOpacity(lit and white or transparent)
            end
            state.rendered=current
            state.color=color
            dirty=false
            log("VALUE","reserve="..current.."/"..capacity)
        end
    end
    local function stop()
        active=false
        detach("stop")
        if worker~=nil then
            local handle=worker
            worker=nil
            local ok,result=pcall(CancelDelayedAction,handle)
            if not ok or result~=true then log("CANCEL_PENDING","worker_inert=true") end
        end
    end
    local function start()
        if disabled or active then return false end
        if type(LoopInGameThreadWithDelay)~="function"
            or type(CancelDelayedAction)~="function"
            or type(StaticConstructObject)~="function"
            or type(FindAllOf)~="function" then
            log("UNAVAILABLE","native_umg_or_scheduler_api")
            return false
        end
        active=true
        local ok,handle=pcall(LoopInGameThreadWithDelay,100,function()
            if not active or disabled then return end
            tick=tick+1
            local done,err=pcall(refresh)
            if not done then
                log("DISABLED","reason="..tostring(err):sub(1,150))
                disabled=true
                stop()
            end
        end)
        if not ok or type(handle)~="number" then
            active=false
            log("UNAVAILABLE","scheduler_registration")
            return false
        end
        worker=handle
        return true
    end
    return {start=start,changed=function(before,after) if before~=after then dirty=true end end,stop=stop}
end

-- SPDX-License-Identifier: MPL-2.0
-- Dev-only UMG overlay: no combat mutations, no CombatHUD writes, no input focus.
-- First layout is provisional; precise LeftBottom_Panel slot requires game A/B.
return function(snapshot, log)
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
            local w,parent=resolve(state.children[i]),resolve(state.root)
            if w and parent and same(w:GetParent(),parent) then
                local ok=pcall(function()
                    w:SetVisibility(1)
                    assert(parent:RemoveChild(w)==true and not valid(w:GetParent()))
                end)
                if not ok then failures=failures+1 end
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
    local function imageBox(w,width,height)
        local b=w.Brush
        assert(not valid(b.ResourceObject) and b.ResourceName:ToString()=="None",
            "brush_asset_not_empty")
        b.DrawAs,b.ImageType,b.Tiling,b.Mirroring=1,0,0,0
        b.ImageSize={X=width,Y=height}
        b.Margin={Left=0,Top=0,Right=0,Bottom=0}
        b.TintColor={SpecifiedColor={R=1,G=1,B=1,A=1},ColorUseRule=0}
        w:SetBrush(b)
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
        local tree,left,status=chosen.WidgetTree,chosen.LeftBottom_Panel,chosen.HUDStatusBarUMG_BP
        if not valid(tree) or cls(tree)~="/Script/UMG.WidgetTree"
            or not same(tree:GetOuter(),chosen) or cls(left)~="/Script/UMG.CanvasPanel"
            or not valid(status) or not same(status:GetParent(),left)
            or not valid(status.APBar) then return end
        return chosen,tree,left,status
    end
    local function mount(owner,capacity)
        local hud,tree,left,status=hudFor(owner)
        if not hud then return end
        generation=generation+1
        local name="StaffReserveHUD_"..generation
        local state={hud=ref(hud),tree=ref(tree),left=ref(left),
            status=ref(status),owner=owner,capacity=capacity,children={},fills={}}
        owned=state -- partial construction remains eligible for own-only cleanup
        local root=create("CanvasPanel",tree,name)
        state.root=ref(root)
        -- Provisional placement on LeftBottom, NOT a change to AP or CombatHUD.
        slot(left,root,205,-20,138,30,0,1,0,1)
        local label=create("TextBlock",tree,name.."_Title",state.children)
        label:SetText(FText("STAFF"))
        label:SetColorAndOpacity({SpecifiedColor={R=0.83,G=0.88,B=0.94,A=1},ColorUseRule=0})
        slot(root,label,0,4,52,22,0,0,0,0)
        for i=1,capacity do
            local x=55+(i-1)*26
            local bg=create("Image",tree,name.."_Bg"..i,state.children)
            imageBox(bg,22,22)
            bg:SetColorAndOpacity({R=0.43,G=0.48,B=0.54,A=0.82})
            slot(root,bg,x,4,22,22,0,0,0,0)
            local fill=create("Image",tree,name.."_Fill"..i,state.children)
            imageBox(fill,16,16)
            slot(root,fill,x+3,7,16,16,0,0,0,0)
            state.fills[i]=ref(fill)
        end
        root:SetVisibility(3) -- SelfHitTestInvisible, no focus/input change
        dirty=true
        log("ATTACHED","slots="..capacity.." owned_widgets="..(#state.children+1))
    end
    local function refresh()
        local current,capacity,owner=snapshot()
        if math.type(current)~="integer" or math.type(capacity)~="integer"
            or capacity<1 or capacity>6 or current<0 or current>capacity
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
        local opacity=status.APBar:GetRenderOpacity() -- read-only CombatHUD fade reference
        assert(type(opacity)=="number" and opacity>=0 and opacity<=1,"invalid_ap_opacity")
        if math.abs(root:GetRenderOpacity()-opacity)>0.001 then root:SetRenderOpacity(opacity) end
        if dirty or current~=state.rendered then
            for i=1,capacity do
                local fill=resolve(state.fills[i])
                assert(fill,"own_fill_lost")
                if i<=current then fill:SetColorAndOpacity({R=0.84,G=0.93,B=1,A=0.98})
                else fill:SetColorAndOpacity({R=0.54,G=0.62,B=0.70,A=0.10}) end
            end
            state.rendered=current
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

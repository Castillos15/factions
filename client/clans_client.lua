class "ClanSystem"

msgColors =
	{
		[ "err" ] = Color ( 255, 0, 0 ),
		[ "info" ] = Color ( 0, 255, 0 ),
		[ "warn" ] = Color ( 255, 100, 0 )
	}

function ClanSystem:__init ( )
	Events:Subscribe ( "ModuleLoad", self, self.ModuleLoad )
end

function ClanSystem:ModuleLoad ( )
	self.active = false
	self.LastTick = 0
	self.playerClans = { }

	self.clanMenu = { }
	self.playerToRow = { }
	self.clanMenu.window = GUI:Window ( "Castillo's Faction system - Menu", Vector2 ( 0.5, 0.5 ) - Vector2 ( 0.3, 0.45 ) / 2, Vector2 ( 0.3, 0.45 ) )
	self.clanMenu.window:SetVisible ( false )
	self.clanMenu.playersList = GUI:SortedList ( Vector2 ( 0.0, 0.0 ), Vector2 ( 0.53, 0.8 ), self.clanMenu.window, { { name = "Player" } } )
	for player in Client:GetPlayers ( ) do
		self:addPlayerToList ( player )
	end
	self:addPlayerToList ( LocalPlayer )

	self.clanMenu.searchEdit = GUI:TextBox ( "", Vector2 ( 0.0, 0.82 ), Vector2 ( 0.53, 0.07 ), "text", self.clanMenu.window )
	self.clanMenu.searchEdit:Subscribe ( "TextChanged", self, self.SearchPlayer )

	self.clanMenu.cLabel = GUI:Label ( "Faction options", Vector2 ( 0.55, 0.01 ), Vector2 ( 0.20, 0.1 ), self.clanMenu.window )
	self.clanMenu.manageClan = GUI:Button ( "Manage", Vector2 ( 0.55, 0.08 ), Vector2 ( 0.20, 0.1 ), self.clanMenu.window )
	self.clanMenu.manageClan:Subscribe ( "Press", self, self.ManageClan )

	self.clanMenu.leaveClan = GUI:Button ( "Leave", Vector2 ( 0.77, 0.08 ), Vector2 ( 0.20, 0.1 ), self.clanMenu.window )
	self.clanMenu.leaveClan:Subscribe ( "Press", self, self.LeaveClan )

	self.clanMenu.invitePlayer = GUI:Button ( "Invite player", Vector2 ( 0.55, 0.19 ), Vector2 ( 0.20, 0.1 ), self.clanMenu.window )
	self.clanMenu.invitePlayer:Subscribe ( "Press", self, self.InvitePlayer )

	self.clanMenu.pLabel = GUI:Label ( "Player options", Vector2 ( 0.55, 0.35 ), Vector2 ( 0.20, 0.1 ), self.clanMenu.window )
	self.clanMenu.clanList = GUI:Button ( "Faction list", Vector2 ( 0.55, 0.41 ), Vector2 ( 0.20, 0.1 ), self.clanMenu.window )
	self.clanMenu.clanList:Subscribe ( "Press", self, self.ClanList )

	self.clanMenu.invitations = GUI:Button ( "Invitations", Vector2 ( 0.77, 0.41 ), Vector2 ( 0.20, 0.1 ), self.clanMenu.window )
	self.clanMenu.invitations:Subscribe ( "Press", self, self.Invitations )

	self.clanMenu.create = GUI:Button ( "Create", Vector2 ( 0.55, 0.52 ), Vector2 ( 0.20, 0.1 ), self.clanMenu.window )
	self.clanMenu.create:Subscribe ( "Press", self, self.ShowCreate )

	self.createClan = { }
	self.createClan.window = GUI:Window ( "Castillo's Faction system - Create faction", Vector2 ( 0.5, 0.5 ) - Vector2 ( 0.2, 0.33 ) / 2, Vector2 ( 0.2, 0.33 ) )
	self.createClan.window:SetVisible ( false )
	self.createClan.nLabel = GUI:Label ( "Faction name:", Vector2 ( 0.0, 0.01 ), Vector2 ( 0.0, 0.0 ), self.createClan.window )
	self.createClan.nLabel:SizeToContents ( )
	self.createClan.nEdit = GUI:TextBox ( "", Vector2 ( 0.0, 0.1 ), Vector2 ( 0.96, 0.1 ), "text", self.createClan.window )
	self.createClan.tLabel = GUI:Label ( "Faction tag", Vector2 ( 0.0, 0.23 ), Vector2 ( 0.0, 0.0 ), self.createClan.window )
	self.createClan.tLabel:SizeToContents ( )
	self.createClan.tEdit = GUI:TextBox ( "", Vector2 ( 0.0, 0.3 ), Vector2 ( 0.96, 0.1 ), "text", self.createClan.window )
	self.createClan.ttLabel = GUI:Label ( "Faction type:", Vector2 ( 0.0, 0.43 ), Vector2 ( 0.0, 0.0 ), self.createClan.window )
	self.createClan.ttLabel:SizeToContents ( )
	self.createClan.type = GUI:ComboBox ( Vector2 ( 0.0, 0.51 ), Vector2 ( 0.96, 0.1 ), self.createClan.window, { "Open", "Closed" } )
	self.createClan.cPick = GUI:Button ( "Faction colour", Vector2 ( 0.0, 0.65 ), Vector2 ( 0.96, 0.10 ), self.createClan.window )
	self.createClan.cPick:Subscribe ( "Press", self, self.Colour )
	self.createClan.create = GUI:Button ( "Create faction", Vector2 ( 0.0, 0.75 ), Vector2 ( 0.96, 0.10 ), self.createClan.window )
	self.createClan.create:Subscribe ( "Press", self, self.Create )

	self.colorPicker = { }
	self.colorPicker.window = GUI:Window ( "Colour", Vector2 ( 0.5, 0.5 ) - Vector2 ( 0.2, 0.42 ) / 2, Vector2 ( 0.2, 0.42 ) )
	self.colorPicker.window:SetVisible ( false )
	self.colorPicker.picker = HSVColorPicker.Create ( )
	self.colorPicker.picker:SetParent ( self.colorPicker.window )
	self.colorPicker.picker:SetSizeRel ( Vector2 ( 1.06, 0.8 ) )
	self.colorPicker.set = GUI:Button ( "Set colour", Vector2 ( 0.0, 0.82 ), Vector2 ( 0.76, 0.070 ), self.colorPicker.window )
	self.colorPicker.set:Subscribe ( "Press", self, self.SetColour )
	self.colorPicker.colour = { 255, 255, 255 }

	self.manageClan = { }
	self.manageClan.rows = { }
	self.manageClan.window = GUI:Window ( "Castillo's Faction system - Faction management", Vector2 ( 0.5, 0.5 ) - Vector2 ( 0.4, 0.60 ) / 2, Vector2 ( 0.4, 0.60 ) )
	self.manageClan.window:SetVisible ( false )
	self.manageClan.mList = GUI:SortedList ( Vector2 ( 0.0, 0.0 ), Vector2 ( 0.64, 0.65 ), self.manageClan.window, { { name = "Name" }, { name = "Rank" }, { name = "Join date" } } )
	self.manageClan.mList:SetButtonsVisible ( true )
	self.manageClan.dLabel = GUI:Label ( "Faction name:", Vector2 ( 0.0, 0.67 ), Vector2 ( 0.0, 0.0 ), self.manageClan.window )
	self.manageClan.dLabel:SizeToContents ( )
	self.manageClan.mLabel = GUI:Label ( "Member options", Vector2 ( 0.66, 0.015 ), Vector2 ( 0.0, 0.0 ), self.manageClan.window )
	self.manageClan.mLabel:SizeToContents ( )
	self.manageClan.ranks = GUI:ComboBox ( Vector2 ( 0.66, 0.06 ), Vector2 ( 0.16, 0.06 ), self.manageClan.window, { "Co-Founder", "Deputy", "Member" } )
	self.manageClan.kick = GUI:Button ( "Kick", Vector2 ( 0.66, 0.14 ), Vector2 ( 0.29, 0.068 ), self.manageClan.window )
	self.manageClan.kick:Subscribe ( "Press", self, self.Kick )
	self.manageClan.sRank = GUI:Button ( "Set rank", Vector2 ( 0.83, 0.06 ), Vector2 ( 0.12, 0.068 ), self.manageClan.window )
	self.manageClan.sRank:Subscribe ( "Press", self, self.SetRank )
	self.manageClan.cLabel = GUI:Label ( "Faction options", Vector2 ( 0.66, 0.23 ), Vector2 ( 0.0, 0.0 ), self.manageClan.window )
	self.manageClan.cLabel:SizeToContents ( )
	self.manageClan.bank = GUI:Button ( "Bank", Vector2 ( 0.68, 0.28 ), Vector2 ( 0.12, 0.068 ), self.manageClan.window )
	self.manageClan.bank:Subscribe ( "Press", self, self.ShowBank )
	self.manageClan.delete = GUI:Button ( "Delete", Vector2 ( 0.82, 0.28 ), Vector2 ( 0.12, 0.068 ), self.manageClan.window )
	self.manageClan.delete:Subscribe ( "Press", self, self.Remove )
	self.manageClan.log = GUI:Button ( "Log", Vector2 ( 0.82, 0.37 ), Vector2 ( 0.12, 0.068 ), self.manageClan.window )
	self.manageClan.log:Subscribe ( "Press", self, self.ShowLog )
	self.manageClan.motd = GUI:Button ( "MOTD", Vector2 ( 0.68, 0.37 ), Vector2 ( 0.12, 0.068 ), self.manageClan.window )
	self.manageClan.motd:Subscribe ( "Press", self, self.ShowMotd )
	--self.manageClan.chat = GUI:Button ( "Chat", Vector2 ( 0.68, 0.38 ), Vector2 ( 0.12, 0.068 ), self.manageClan.window )

	self.bank = { }
	self.bank.window = GUI:Window ( "Castillo's Faction system - Bank", Vector2 ( 0.5, 0.5 ) - Vector2 ( 0.2, 0.21 ) / 2, Vector2 ( 0.2, 0.21 ) )
	self.bank.window:SetVisible ( false )
	self.bank.balance = GUI:Label ( "Total balance: $0", Vector2 ( 0.0, 0.02 ), Vector2 ( 0.0, 0.0 ), self.bank.window )
	self.bank.balance:SizeToContents ( )
	self.bank.aLabel = GUI:Label ( "Amount:", Vector2 ( 0.0, 0.33 ), Vector2 ( 0.0, 0.0 ), self.bank.window )
	self.bank.aLabel:SizeToContents ( )
	self.bank.aEdit = GUI:TextBox ( "0", Vector2 ( 0.0, 0.45 ), Vector2 ( 0.96, 0.15 ), "numeric", self.bank.window )
	self.bank.deposit = GUI:Button ( "Deposit", Vector2 ( 0.0, 0.63 ), Vector2 ( 0.46, 0.15 ), self.bank.window )
	self.bank.deposit:Subscribe ( "Press", self, self.Deposit )
	self.bank.withdraw = GUI:Button ( "Withdraw", Vector2 ( 0.49, 0.63 ), Vector2 ( 0.46, 0.15 ), self.bank.window )
	self.bank.withdraw:Subscribe ( "Press", self, self.Withdraw )

	self.confirm = { }
	self.confirm.action = ""
	self.confirm.window = GUI:Window ( "Confirm action", Vector2 ( 0.5, 0.5 ) - Vector2 ( 0.13, 0.13 ) / 2, Vector2 ( 0.13, 0.13 ) )
	self.confirm.window:SetVisible ( false )
	self.confirm.label = GUI:Label ( "Are you sure that you want to carry on with this action?", Vector2 ( 0.0, 0.0 ), Vector2 ( 0.90, 0.23 ), self.confirm.window )
	self.confirm.label:SetWrap ( true )
	self.confirm.accept = GUI:Button ( "Yes", Vector2 ( 0.0, 0.35 ), Vector2 ( 0.9, 0.25 ), self.confirm.window )
	self.confirm.accept:Subscribe ( "Press", self, self.Confirm )

	self.invitations = { }
	self.invitations.rows = { }
	self.invitations.window = GUI:Window ( "Castillo's Faction system - Invitations", Vector2 ( 0.5, 0.5 ) - Vector2 ( 0.25, 0.45 ) / 2, Vector2 ( 0.25, 0.45 ) )
	self.invitations.window:SetVisible ( false )
	self.invitations.list = GUI:SortedList ( Vector2 ( 0.0, 0.0 ), Vector2 ( 0.97, 0.8 ), self.invitations.window, { { name = "Faction" } } )
	self.invitations.join = GUI:Button ( "Join faction", Vector2 ( 0.0, 0.8 ), Vector2 ( 0.97, 0.1 ), self.invitations.window )
	self.invitations.join:Subscribe ( "Press", self, self.AcceptInvite )

	self.clanList = { }
	self.clanList.rows = { }
	self.clanList.window = GUI:Window ( "Castillo's Faction system - Faction list", Vector2 ( 0.5, 0.5 ) - Vector2 ( 0.25, 0.45 ) / 2, Vector2 ( 0.25, 0.45 ) )
	self.clanList.window:SetVisible ( false )
	self.clanList.list = GUI:SortedList ( Vector2 ( 0.0, 0.0 ), Vector2 ( 0.97, 0.8 ), self.clanList.window, { { name = "Faction" }, { name = "Type" } } )
	self.clanList.join = GUI:Button ( "Join faction", Vector2 ( 0.0, 0.8 ), Vector2 ( 0.97, 0.1 ), self.clanList.window )
	self.clanList.join:Subscribe ( "Press", self, self.JoinClan )

	self.motd = { }
	self.motd.window = GUI:Window ( "Castillo's Faction system - MOTD", Vector2 ( 0.5, 0.5 ) - Vector2 ( 0.30, 0.50 ) / 2, Vector2 ( 0.30, 0.50 ) )
	self.motd.window:SetVisible ( false )
	self.motd.content = GUI:TextBox ( "", Vector2 ( 0.0, 0.0 ), Vector2 ( 0.96, 0.80 ), "multiline", self.motd.window )
	self.motd.content:SetEnabled ( false )
	self.motd.update = GUI:Button ( "Update MOTD", Vector2 ( 0.25, 0.82 ), Vector2 ( 0.50, 0.07 ), self.motd.window )
	self.motd.update:Subscribe ( "Press", self, self.UpdateMotd )

	self.log = { }
	self.log.window = GUI:Window ( "Castillo's Faction system - Log", Vector2 ( 0.5, 0.5 ) - Vector2 ( 0.27, 0.50 ) / 2, Vector2 ( 0.27, 0.50 ) )
	self.log.window:SetVisible ( false )
	self.log.list = GUI:SortedList ( Vector2 ( 0.0, 0.0 ), Vector2 ( 0.97, 0.80 ), self.log.window, { { name = "Action" } } )
	self.log.clear = GUI:Button ( "Clear Log", Vector2 ( 0.25, 0.82 ), Vector2 ( 0.50, 0.07 ), self.log.window )
	self.log.clear:Subscribe ( "Press", self, self.ClearLog )

	Network:Send ( "Clans:RequestSyncList", LocalPlayer )
	Events:Subscribe ( "PostTick", self, self.PostTick )
	Network:Subscribe ( "Clans:SyncPlayers", self, self.SyncPlayerClans )
	Network:Subscribe ( "Clans:ReceiveData", self, self.ReceiveData )
	Network:Subscribe ( "Clans:UpdateBankLabel", self, self.UpdateBankLabel )
	Network:Subscribe ( "Clans:ReceiveInvitations", self, self.ReceiveInvitations )
	Network:Subscribe ( "Clans:ReceiveClans", self, self.ReceiveClans )
	Events:Subscribe ( "KeyUp", self, self.KeyUp )
	Events:Subscribe ( "LocalPlayerInput", self, self.LocalPlayerInput )
	Events:Subscribe ( "LocalPlayerExplosionHit", self, self.WeaponDamage )
	Events:Subscribe ( "LocalPlayerBulletHit", self, self.WeaponDamage )
	Events:Subscribe ( "LocalPlayeForcePulseHit", self, self.WeaponDamage )
	Events:Subscribe ( "PlayerJoin", self, self.PlayerJoin )
	Events:Subscribe ( "PlayerQuit", self, self.PlayerQuit )
	self.clanMenu.window:Subscribe ( "WindowClosed", self, self.WindowClosed )
    Events:Fire ( "HelpAddItem",
        {
            name = "SAUR factions",
            text = 
                "Factions system scripted and designed by Castillo\n\nFeatures:\nCreate faction - Two types: Public or Invite Only\nInvite players\nSet member ranks\nFaction bank - Deposit/Withdraw\nFriendly fire disabled ( Can't kill between faction members)\nRead/Set MOTD\nView/Clear log\n\nPress F7 to access the factions menu"
        }
	)
	Events:Subscribe ( "ModuleUnload", self, self.Unload )
end

function ClanSystem:Unload ( )
    Events:Fire ( "HelpRemoveItem",
        {
            name = "SAUR factions"
        }
	)
end

function ClanSystem:GetActive ( )
	return self.active
end

function ClanSystem:SetActive ( state )
	self.active = state
	self.clanMenu.window:SetVisible ( self.active )
	Mouse:SetVisible ( self.active )
	if ( not state ) then
		self.createClan.window:SetVisible ( false )
		self.colorPicker.window:SetVisible ( false )
		self.manageClan.window:SetVisible ( false )
		self.bank.window:SetVisible ( false )
		self.confirm.window:SetVisible ( false )
		self.invitations.window:SetVisible ( false )
		self.clanList.window:SetVisible ( false )
	end
end

function ClanSystem:KeyUp ( args )
	if ( args.key == VirtualKey.F7 ) then
		self:SetActive ( not self:GetActive ( ) )
	end
end

function ClanSystem:LocalPlayerInput ( args )
	if ( self:GetActive ( ) and Game:GetState ( ) == GUIState.Game ) then
		return false
	end
end

function ClanSystem:WindowClosed ( )
	self:SetActive ( false )
end

function ClanSystem:SetColour ( )
	local color = self.colorPicker.picker:GetColor ( )
	self.colorPicker.colour = { color.r, color.g, color.b }
	self.colorPicker.window:SetVisible ( false )
end

function ClanSystem:Colour ( )
	self.colorPicker.window:SetVisible ( not self.colorPicker.window:GetVisible ( ) )
end

function ClanSystem:ManageClan ( )
	Network:Send ( "Clans:GetData" )
end

function ClanSystem:LeaveClan ( )
	self.confirm.window:SetVisible ( true )
	self.confirm.action = "leave"
end

function ClanSystem:InvitePlayer ( )
	local row = self.clanMenu.playersList:GetSelectedRow ( )
	if ( row ~= nil ) then
		local player = row:GetDataObject ( "id" )
		Network:Send ( "Clans:Invite", player )
	end
end

function ClanSystem:ClanList ( )	
	self.clanList.window:SetVisible ( true )
	Network:Send ( "Clans:GetClans" )
end

function ClanSystem:Invitations ( )
	self.invitations.window:SetVisible ( true )
	Network:Send ( "Clans:Invitations" )
end

function ClanSystem:ReceiveInvitations ( invitations )
	self.invitations.list:Clear ( )
	if ( type ( invitations ) == "table" ) then
		for index, clan in ipairs ( invitations ) do
			self.invitations.rows [ clan ] = self.invitations.list:AddItem ( tostring ( clan ) )
			self.invitations.rows [ clan ]:SetDataNumber ( "id", index )
		end
	end
end

function ClanSystem:AcceptInvite ( )
	local row = self.invitations.list:GetSelectedRow ( )
	if ( row ~= nil ) then
		local clan = row:GetCellText ( 0 )
		local index = row:GetDataNumber ( "id" )
		Network:Send ( "Clans:AcceptInvite", { clan = clan, index = index } )
		self.invitations.window:SetVisible ( false )
	end
end

function ClanSystem:ReceiveClans ( clans )
	self.clanList.list:Clear ( )
	for name, data in pairs ( clans ) do
		local item = self.clanList.list:AddItem ( tostring ( name ) )
		item:SetCellText ( 1, ( data.type == "Open" and "Public" or "Invite Only" ) )
		table.insert ( self.clanList.rows, item )
	end
end

function ClanSystem:JoinClan ( )
	local row = self.clanList.list:GetSelectedRow ( )
	if ( row ~= nil ) then
		local clan = row:GetCellText ( 0 )
		Network:Send ( "Clans:JoinClan", clan )
		self.clanList.window:SetVisible ( false )
	end
end

function ClanSystem:ShowCreate ( )
	self.createClan.window:SetVisible ( true )
end

function ClanSystem:Create ( )
	local args = { }
	args.name = self.createClan.nEdit:GetText ( )
	if ( args.name ~= "" ) then
		args.tag = self.createClan.tEdit:GetText ( )
		args.colour = table.concat ( self.colorPicker.colour, ", " )
		args.type = self.createClan.type:GetText ( )
		Network:Send ( "Clans:Create", args )
		self.createClan.window:SetVisible ( false )
	else
		LocalPlayer:Message ( "Faction: Please fill the name field.", "err" )
	end
end

function ClanSystem:ReceiveData ( args )
	self.manageClan.window:SetVisible ( true )
	self.manageClan.dLabel:SetText ( "Faction name: ".. tostring ( args.clanData.name ) .."\n\nFaction tag: ".. tostring ( args.clanData.tag ) .."\n\nFaction type: ".. ( args.clanData.type == "Open" and "Public" or "Invite Only" ) .."\n\nTotal members: ".. tostring ( #args.members ) .."\n\nCreation date: ".. tostring ( args.clanData.creationDate ) )
	self.manageClan.dLabel:SizeToContents ( )
	self.motd.content:SetText ( args.clanData.motd )
	self.bank.balance:SetText ( "Total balance: $".. convertNumberToString ( args.clanData.bank ) )
	self.bank.balance:SizeToContents ( )
	self.manageClan.mList:Clear ( )
	for _, member in ipairs ( args.members ) do
		local item = self.manageClan.mList:AddItem ( tostring ( member.name ) )
		item:SetCellText ( 1, tostring ( member.rank ) )
		item:SetCellText ( 2, tostring ( member.joinDate ) )
		item:SetDataString ( "id", member.steamID )
		table.insert ( self.manageClan.rows, item )
	end
	self.log.list:Clear ( )
	if ( type ( args.messages ) == "table" ) then
		for _, msg in ipairs ( args.messages ) do
			if ( msg.type == "log" ) then
				self.log.list:AddItem ( tostring ( msg.message ) )
			end
		end
	end
end

function ClanSystem:Kick ( )
	local row = self.manageClan.mList:GetSelectedRow ( )
	if ( row ~= nil ) then
		local steamID = row:GetDataString ( "id" )
		local name = row:GetCellText ( 0 )
		local rank = row:GetCellText ( 1 )
		Network:Send ( "Clans:Kick", { name = name, steamID = steamID, rank = rank } )
	end
end

function ClanSystem:SetRank ( )
	local row = self.manageClan.mList:GetSelectedRow ( )
	if ( row ~= nil ) then
		local steamID = row:GetDataString ( "id" )
		local name = row:GetCellText ( 0 )
		local rank = self.manageClan.ranks:GetText ( )
		local curRank = row:GetCellText ( 1 )
		Network:Send ( "Clans:SetRank", { name = name, steamID = steamID, curRank = curRank, rank = rank } )
	end
end

function ClanSystem:ShowBank ( )
	self.bank.window:SetVisible ( not self.bank.window:GetVisible ( ) )
end

function ClanSystem:ShowLog ( )
	self.log.window:SetVisible ( true )
end

function ClanSystem:ShowMotd ( )
	self.motd.window:SetVisible ( true )
end

function ClanSystem:Remove ( )
	self.confirm.window:SetVisible ( true )
	self.confirm.action = "remove"
end

function ClanSystem:Chat ( )
end

function ClanSystem:Deposit ( )
	local amount = tonumber ( self.bank.aEdit:GetText ( ) ) or 0
	if ( amount > 0 ) then
		Network:Send ( "Clans:UpdateBank", { action = "deposit", amount = amount } )
	else
		LocalPlayer:Message ( "Faction: Invalid amount.", "err" )
	end
end

function ClanSystem:Withdraw ( )
	local amount = tonumber ( self.bank.aEdit:GetText ( ) ) or 0
	if ( amount > 0 ) then
		Network:Send ( "Clans:UpdateBank", { action = "withdraw", amount = amount } )
	else
		LocalPlayer:Message ( "Faction: Invalid amount.", "err" )
	end
end

function ClanSystem:UpdateBankLabel ( amount )
	self.bank.balance:SetText ( "Total balance: $".. convertNumberToString ( amount ) )
	self.bank.balance:SizeToContents ( )
end

function ClanSystem:Confirm ( )
	if ( self.confirm.action == "remove" ) then
		Network:Send ( "Clans:Remove" )
	elseif ( self.confirm.action == "leave" ) then
		Network:Send ( "Clans:Leave" )
	end
	self:SetActive ( false )
	self.confirm.window:SetVisible ( false )
end

function ClanSystem:addPlayerToList ( player )
	local item = self.clanMenu.playersList:AddItem ( tostring ( player:GetName ( ) ) )
	item:SetVisible ( true )
	item:SetDataObject ( "id", player )
	self.playerToRow [ player:GetId ( ) ] = item
end

function ClanSystem:PlayerJoin ( args )
	self:addPlayerToList ( args.player )
end

function ClanSystem:PlayerQuit ( args )
	if ( self.playerToRow [ args.player:GetId ( ) ] ) then
		self.clanMenu.playersList:RemoveItem ( self.playerToRow [ args.player:GetId ( ) ] )
	end
end

function ClanSystem:SearchPlayer ( )
	local text = self.clanMenu.searchEdit:GetText ( ):lower ( )
	if ( text ~= "" and text:len ( ) > 0 ) then
		for _, item in pairs ( self.playerToRow ) do
			if ( type ( item ) == "userdata" ) then
				item:SetVisible ( false )
				if item:GetCellText ( 0 ):lower ( ):find ( text, 1, true ) then
					item:SetVisible ( true )
				end
			end
		end
	else
		for _, item in pairs ( self.playerToRow ) do
			if ( type ( item ) == "userdata" ) then
				item:SetVisible ( true )
			end
		end
	end
end

function ClanSystem:SyncPlayerClans ( players )
	self.playerClans = players
end

function ClanSystem:PostTick ( )
	if ( Client:GetElapsedSeconds ( ) - self.LastTick >= 5 ) then
		Network:Send ( "Clans:RequestSyncList", LocalPlayer )
		self.LastTick = Client:GetElapsedSeconds ( )
	end
end

function ClanSystem:GetPlayerClan ( player )
	if ( type ( player ) == "userdata" ) then
		if ( self.playerClans [ player:GetId ( ) ] ) then
			return self.playerClans [ player:GetId ( ) ]
		else
			return false
		end
	else
		return false
	end
end

function ClanSystem:WeaponDamage ( args )
	if ( type ( args.attacker ) == "userdata" ) then
		if ( args.attacker:GetId ( ) ~= LocalPlayer:GetId ( ) ) then
			local lpClan = self:GetPlayerClan ( LocalPlayer )
			local atClan = self:GetPlayerClan ( args.attacker )
			if ( lpClan and atClan ) then
				if ( lpClan == atClan ) then
					return false
				end
			end
		end
	end
end

function ClanSystem:UpdateMotd ( )
	local text = self.motd.content:GetText ( )
	Network:Send ( "Clans:UpdateMOTD", text )
end

function ClanSystem:ClearLog ( )
	Network:Send ( "Clans:ClearLog" )
	self.log.window:SetVisible ( false )
	self.log.list:Clear ( )
end

clanSystem = ClanSystem ( )

function LocalPlayer:Message ( msg, color )
	Chat:Print ( msg, msgColors [ color ] )
end

function convertNumberToString ( value )
	if ( value and tonumber ( value ) ) then
		local value = tostring ( value )
		if string.sub ( value, 1, 1 ) == "-" then
			return "-".. setCommasInNumber ( string.sub ( value, 2, #value ) )
		else
			return setCommasInNumber ( value )
		end
	end

	return false
end

function setCommasInNumber ( value )
	if ( #value > 3 ) then
		return setCommasInNumber ( string.sub ( value, 1, #value - 3 ) ) ..",".. string.sub ( value, #value - 2, #value )
	else
		return value
	end
end
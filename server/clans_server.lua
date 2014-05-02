class "ClanSystem"

msgColors =
	{
		[ "err" ] = Color ( 255, 0, 0 ),
		[ "info" ] = Color ( 0, 255, 0 ),
		[ "warn" ] = Color ( 255, 100, 0 )
	}

function ClanSystem:__init ( )
	self.LastTick = 0
	self.playerList = { }
	self.clans = { }
	self.clanMembers = { }
	self.playerClan = { }
	self.steamIDToPlayer = { }
	self.invitations = { }
	self.clanMessages = { }
	self.permissions =
		{
			[ "Founder" ] =
				{
					kick = true,
					invite = true,
					setRank = true,
					setMotd = true,
					clearLog = true
				},
			[ "Co-Founder" ] =
				{
					kick = true,
					invite = true,
					setRank = true,
					setMotd = true,
					clearLog = true
				},
			[ "Deputy" ] =
				{
					kick = true,
					invite = true,
					setRank = false,
					setMotd = false,
					clearLog = false
				},
			[ "Member" ] =
				{
					kick = false,
					invite = false,
					setRank = false,
					setMotd = false,
					clearLog = false
				},
		}

	for player in Server:GetPlayers ( ) do
		self.steamIDToPlayer [ player:GetSteamId ( ).id ] = player
	end

	Network:Subscribe ( "Clans:Create", self, self.AddClan )
	Network:Subscribe ( "Clans:Remove", self, self.RemoveClan )
	Network:Subscribe ( "Clans:GetData", self, self.GetData )
	Network:Subscribe ( "Clans:UpdateBank", self, self.UpdateBank )
	Network:Subscribe ( "Clans:Leave", self, self.LeaveClan )
	Network:Subscribe ( "Clans:Invite", self, self.InvitePlayer )
	Network:Subscribe ( "Clans:Invitations", self, self.GetInvitations )
	Network:Subscribe ( "Clans:AcceptInvite", self, self.AcceptInvite )
	Network:Subscribe ( "Clans:GetClans", self, self.GetClans )
	Network:Subscribe ( "Clans:JoinClan", self, self.JoinClan )
	Network:Subscribe ( "Clans:Kick", self, self.KickPlayer )
	Network:Subscribe ( "Clans:SetRank", self, self.SetPlayerRank )
	Network:Subscribe ( "Clans:RequestSyncList", self, self.SendPlayerList )
	Network:Subscribe ( "Clans:UpdateMOTD", self, self.UpdateMOTD )
	Network:Subscribe ( "Clans:ClearLog", self, self.ClearLog )
	Events:Subscribe ( "PlayerChat",  self, self.FactionChat )
	Events:Subscribe ( "PostTick", self, self.SyncPlayers )
	Events:Subscribe ( "PlayerQuit", self, self.PlayerQuit )

	SQL:Execute ( "CREATE TABLE IF NOT EXISTS clans ( name VARCHAR UNIQUE, creator VARCHAR, tag VARCHAR, colour VARCHAR, creationDate VARCHAR, bank INT, type VARCHAR, motd VARCHAR )" )
	SQL:Execute ( "CREATE TABLE IF NOT EXISTS clan_members ( steamID VARCHAR UNIQUE, clan VARCHAR, name VARCHAR, rank VARCHAR, joinDate VARCHAR )" )
	SQL:Execute ( "CREATE TABLE IF NOT EXISTS clan_messages ( clan VARCHAR, type VARCHAR, message VARCHAR, date VARCHAR )" )
	--SQL:Execute ( "ALTER TABLE clans ADD COLUMN motd VARCHAR" )
	--SQL:Execute ( "ALTER TABLE clan_messages ADD COLUMN date VARCHAR" )

	local query = SQL:Query ( "SELECT * FROM clans" )
	local result = query:Execute ( )
	if ( #result > 0 ) then
		for _, clan in ipairs ( result ) do
			self.clans [ clan.name ] =
				{
					name = clan.name,
					creator = clan.creator,
					tag = clan.tag,
					colour = clan.colour,
					creationDate = clan.creationDate,
					bank = clan.bank,
					type = clan.type,
					motd = clan.motd
				}
			self.clanMembers [ clan.name ] = { }
			self.clanMessages [ clan.name ] = { }
		end
	end
	print ( tostring ( #result ) .." faction(s) loaded!" )

	local query = SQL:Query ( "SELECT * FROM clan_members" )
	local result = query:Execute ( )
	if ( #result > 0 ) then
		for _, member in ipairs ( result ) do
			if ( self.clanMembers [ member.clan ] ) then
				table.insert (
					self.clanMembers [ member.clan ],
					{
						steamID = member.steamID,
						clan = member.clan,
						name = member.name,
						rank = member.rank,
						joinDate = member.joinDate
					}
				)
				self.playerClan [ member.steamID ] = { member.clan, #self.clanMembers [ member.clan ] }
			end
		end
	end
	print ( tostring ( #result ) .." faction member(s) loaded!" )

	local query = SQL:Query ( "SELECT * FROM clan_messages" )
	local result = query:Execute ( )
	if ( #result > 0 ) then
		for _, msg in ipairs ( result ) do
			if ( self.clanMessages [ msg.clan ] ) then
				table.insert (
					self.clanMessages [ msg.clan ],
					{
						clan = msg.clan,
						type = msg.type,
						message = msg.message
					}
				)
			end
		end
	end
	print ( tostring ( #result ) .." faction message(s) loaded!" )
end

function ClanSystem:PlayerQuit ( args )
	self.playerList [ args.player:GetId ( ) ] = nil
end

function ClanSystem:SendPlayerList ( player )
	Network:Send ( player, "Clans:SyncPlayers", self.playerList )
end 

function ClanSystem:SyncPlayers ( )
	if ( Server:GetElapsedSeconds ( ) - self.LastTick >= 4 ) then
		for player in Server:GetPlayers ( ) do
			local clan = self:GetPlayerClan ( player )
			self.playerList [ player:GetId ( ) ] = clan
		end

		self.LastTick = Server:GetElapsedSeconds ( )
	end
end

function ClanSystem:AddClan ( args, player )
	local clan = self:GetPlayerClan ( player )
	if ( clan ) then
		player:Message ( "Faction: You're already part of a faction.", "err" )
		return false
	end

	if ( not self:Exists ( args.name ) ) then
		local theDate = os.date ( "%c" )
		local cmd = SQL:Command ( "INSERT INTO clans ( name, creator, tag, colour, creationDate, bank, type ) VALUES ( ?, ?, ?, ?, ?, ?, ? )" )
		cmd:Bind ( 1, args.name )
		cmd:Bind ( 2, player:GetSteamId ( ).id )
		cmd:Bind ( 3, args.tag )
		cmd:Bind ( 4, args.colour )
		cmd:Bind ( 5, theDate )
		cmd:Bind ( 6, 0 )
		cmd:Bind ( 7, args.type )
		cmd:Execute ( )
		self.clans [ args.name ] =
			{
				name = args.name,
				creator = player:GetSteamId ( ).id,
				tag = args.tag,
				colour = args.colour,
				creationDate = theDate,
				bank = 0,
				type = args.type,
				motd = ""
			}
		self.clanMembers [ args.name ] = { }
		player:Message ( "Faction: You have created the faction ".. tostring ( args.name ) .."!", "info" )
		self:AddMember (
			{
				player = player,
				clan = args.name,
				rank = "Founder"
			}
		)
	else
		player:Message ( "Faction: A faction with this name already exists!", "err" )
	end
end

function ClanSystem:RemoveClan ( _, player )
	local name = self:GetPlayerClan ( player )
	if ( name ) then
		if self:Exists ( name ) then
			local cmd = SQL:Command ( "DELETE FROM clans WHERE name = ( ? )" )
			cmd:Bind ( 1, name )
			cmd:Execute ( )
			local cmd = SQL:Command ( "DELETE FROM clan_members WHERE clan = ( ? )" )
			cmd:Bind ( 1, name )
			cmd:Execute ( )
			self.clans [ name ] = nil
			for _, member in ipairs ( self.clanMembers [ name ] ) do
				self.playerClan [ member.steamID ] = nil
			end
			self.clanMembers [ name ] = nil
			player:Message ( "Faction: You have removed the faction!", "warn" )
		else
			player:Message ( "Faction: The faction doesn't exist.", "err" )
		end
	else
		player:Message ( "Faction: You ain't in a faction.", "err" )
	end
end

function ClanSystem:AddMember ( args )
	local theDate = os.date ( "%c" )
	local cmd = SQL:Command ( "INSERT INTO clan_members ( steamID, clan, name, rank, joinDate ) VALUES ( ?, ?, ?, ?, ? )" )
	cmd:Bind ( 1, args.player:GetSteamId ( ).id )
	cmd:Bind ( 2, args.clan )
	cmd:Bind ( 3, args.player:GetName ( ) )
	cmd:Bind ( 4, args.rank )
	cmd:Bind ( 5, theDate )
	cmd:Execute ( )
	table.insert (
		self.clanMembers [ args.clan ],
		{
			steamID = args.player:GetSteamId ( ).id,
			clan = args.clan,
			name = args.player:GetName ( ),
			rank = args.rank,
			joinDate = theDate
		}
	)
	self.playerClan [ args.player:GetSteamId ( ).id ] = { args.clan, #self.clanMembers [ args.clan ] }
	args.player:Message ( "Faction: You have been added to ".. tostring ( args.clan ) .."!", "info" )
	self:AddMessage ( args.clan, "log", args.player:GetName ( ) .." joined the faction." )
end

function ClanSystem:RemoveMember ( args )
	local cmd = SQL:Command ( "DELETE FROM clan_members WHERE clan = ( ? ) AND steamID = ( ? )" )
	cmd:Bind ( 1, args.clan )
	cmd:Bind ( 2, args.steamID )
	cmd:Execute ( )
	local data = self.playerClan [ args.steamID ]
	if ( data ) then
		table.remove ( self.clanMembers [ args.clan ], data [ 2 ] )
	end
	self.playerClan [ args.steamID ] = nil
end

function ClanSystem:Exists ( name )
	return ( self.clans [ name ] and true or false )
end

function ClanSystem:GetPlayerClan ( player )
	if ( type ( player ) == "userdata" ) then
		if ( self.playerClan [ player:GetSteamId ( ).id ] ) then
			return self.playerClan [ player:GetSteamId ( ).id ] [ 1 ], self.playerClan [ player:GetSteamId ( ).id ] [ 2 ]
		else
			return false
		end
	else
		return false
	end
end

function ClanSystem:GetData ( _, player )
	local clan = self:GetPlayerClan ( player )
	if ( clan ) then
		local args = { }
		args.members = self.clanMembers [ clan ]
		args.clanData = self.clans [ clan ]
		args.messages = self.clanMessages [ clan ]
		Network:Send ( player, "Clans:ReceiveData", args )
	else
		player:Message ( "Faction: You ain't in a faction.", "err" )
	end
end

function ClanSystem:UpdateBank ( args, player )
	local update = false
	local clan = self:GetPlayerClan ( player )
	if ( clan ) then
		if ( args.action == "deposit" ) then
			if ( player:GetMoney ( ) >= args.amount ) then
				player:Message ( "Faction: You have deposited $".. convertNumberToString ( args.amount ) .."!", "info" )
				player:SetMoney ( player:GetMoney ( ) - args.amount )
				self:AddMessage ( clan, "log", player:GetName ( ) .." deposited $".. tostring ( convertNumberToString ( args.amount ) ) )
				update = true
			else
				player:Message ( "Faction: You don't have $".. convertNumberToString ( args.amount ) .."!", "err" )
			end
		elseif ( args.action == "withdraw" ) then
			if ( tonumber ( self:GetClanData ( clan, "bank" ) ) >= args.amount ) then
				player:Message ( "Faction: You have withdrawn $".. convertNumberToString ( args.amount ) .."!", "info" )
				player:SetMoney ( player:GetMoney ( ) + args.amount )
				self:AddMessage ( clan, "log", player:GetName ( ) .." withdrawn $".. tostring ( convertNumberToString ( args.amount ) ) )
				update = true
			else
				player:Message ( "Faction: The bank doesn't have $".. convertNumberToString ( args.amount ) .."!", "err" )
			end
		end
		if ( update ) then
			local amount = ( args.action == "deposit" and ( self:GetClanData ( clan, "bank" ) + args.amount ) or ( self:GetClanData ( clan, "bank" ) - args.amount ) )
			local transaction = SQL:Transaction ( )
			local query = SQL:Command ( "UPDATE clans SET bank = ? WHERE name = ?" )
			query:Bind ( 1, amount )
			query:Bind ( 2, clan )
			query:Execute ( )
			transaction:Commit ( )
			self:SetClanData ( clan, "bank", amount )
			Network:Send ( player, "Clans:UpdateBankLabel", amount )
		end
	end
end

function ClanSystem:LeaveClan ( _, player )
	local clan, index = self:GetPlayerClan ( player )
	if ( clan and index ) then
		local steamID = player:GetSteamId ( ).id
		local member = self.clanMembers [ clan ] [ index ]
		if ( member ) then
			if ( member.steamID == steamID ) then
				if ( member.rank ~= "Founder" ) then
					local args = { }
					args.clan = clan
					args.steamID = steamID
					self:RemoveMember ( args )
					player:Message ( "Faction: You have left the faction.", "warn" )
					self:AddMessage ( clan, "log", player:GetName ( ) .." left the faction." )
				else
					player:Message ( "Faction: You can't leave the faction as you're the leader of it.", "err" )
				end
			else
				player:Message ( "Faction: An error has occured, contact an admin.", "err" )
			end
		else
			player:Message ( "Faction: An error has occured, contact an admin.", "err" )
		end
	else
		player:Message ( "Faction: You ain't in a faction.", "err" )
	end
end

function ClanSystem:InvitePlayer ( target, player )
	local clan, index = self:GetPlayerClan ( player )
	if ( clan and index ) then
		if ( type ( target ) == "userdata" ) then
			if self:IsPlayerAllowedTo ( { player = player, action = "invite" } ) then
				local tClan = self:GetPlayerClan ( target )
				if ( not tClan ) then
					self:AddInvitation ( target, clan )
					player:Message ( "Faction:  You have invited ".. target:GetName ( ) .." to the faction.", "info" )
					self:AddMessage ( clan, "log", player:GetName ( ) .." invited ".. tostring ( target:GetName ( ) ) .."." )
				else
					player:Message ( "Faction: This player is already in a faction.", "err" )
				end
			else
				player:Message ( "Faction: You can't use this function.", "err" )
			end
		else
			player:Message ( "Faction: Invalid player.", "err" )
		end
	else
		player:Message ( "Faction: You ain't in a faction.", "err" )
	end
end

function ClanSystem:GetClanData ( clan, data )
	local clanData = self.clans [ clan ]
	if ( type ( clanData ) == "table" ) then
		return clanData [ data ]
	end

	return false
end

function ClanSystem:SetClanData ( clan, data, value )
	local clanData = self.clans [ clan ]
	if ( type ( clanData ) == "table" ) then
		self.clans [ clan ] [ data ] = value
		return true
	end

	return false
end

function ClanSystem:AddInvitation ( player, clan )
	if ( type ( player ) == "userdata" ) then
		if self:Exists ( clan ) then
			if ( not self.invitations [ player:GetId ( ) ] ) then
				self.invitations [ player:GetId ( ) ] = { }
			end
			player:Message ( "Faction: You have been invited to ".. tostring ( clan ) .."!", "info" )
			table.insert ( self.invitations [ player:GetId ( ) ], clan )
		end
	end
end

function ClanSystem:GetInvitations ( _, player )
	Network:Send ( player, "Clans:ReceiveInvitations", self.invitations [ player:GetId ( ) ] )
end

function ClanSystem:AcceptInvite ( args, player )
	if self:Exists ( args.clan ) then
		local clan = self:GetPlayerClan ( player )
		if ( not clan ) then
			self:AddMember (
				{
					player = player,
					clan = args.clan,
					rank = "Member"
				}
			)
			table.remove ( self.invitations [ player:GetId ( ) ], args.index )
		else
			player:Message ( "Faction: You're already part of a faction.", "err" )
		end
	else
		player:Message ( "Faction: The faction no longer exists.", "err" )
	end
end

function ClanSystem:GetClans ( _, player )
	Network:Send ( player, "Clans:ReceiveClans", self.clans )
end

function ClanSystem:JoinClan ( clan, player )
	if self:Exists ( clan ) then
		local pClan = self:GetPlayerClan ( player )
		if ( not pClan ) then
			if ( self.clans [ clan ].type == "Open" ) then
				self:AddMember (
					{
						player = player,
						clan = clan,
						rank = "Member"
					}
				)
			else
				player:Message ( "Faction: This is an invite-only faction.", "err" )
			end
		else
			player:Message ( "Faction: You're already part of a faction.", "err" )
		end
	else
		player:Message ( "Faction: The faction no longer exists.", "err" )
	end
end

function ClanSystem:KickPlayer ( args, player )
	local clan = self:GetPlayerClan ( player )
	if ( clan ) then
		if self:IsPlayerAllowedTo ( { player = player, action = "kick" } ) then
			local member = self.playerClan [ args.steamID ]
			if ( member ) then
				if ( args.rank ~= "Founder" ) then
					local margs = { }
					margs.clan = clan
					margs.steamID = args.steamID
					self:RemoveMember ( margs )
					player:Message ( "Faction: You have kicked ".. tostring ( args.name ) .."!", "warn" )
					self:GetData ( nil, player )
					self:AddMessage ( clan, "log", player:GetName ( ) .." kicked ".. tostring ( args.name ) .."." )
				else
					player:Message ( "Faction: The founder of the faction cannot be kicked.", "err" )
				end
			else
				player:Message ( "Faction: Member not found.", "err" )
			end
		else
			player:Message ( "Faction: You can't use this function.", "err" )
		end
	else
		player:Message ( "Faction: You ain't in a faction.", "err" )
	end
end

function ClanSystem:SetPlayerRank ( args, player )
	local clan = self:GetPlayerClan ( player )
	if ( clan ) then
		local myRank = self:GetMemberData ( { steamID = player:GetSteamId ( ).id, data = "rank" } )
		if self:IsPlayerAllowedTo ( { player = player, action = "setRank" } ) then
			local memberRank = self:GetMemberData ( { steamID = args.steamID, data = "rank" } )
			if ( memberRank ) then
				if ( memberRank ~= "Founder" ) then
					if ( memberRank ~= myRank ) then
						if ( memberRank ~= args.rank ) then
							if self:SetMemberData ( { steamID = args.steamID, data = "rank", value = args.rank } ) then
								self:GetData ( nil, player )
								player:Message ( "Faction: You have set ".. tostring ( args.name ) .."'s rank to ".. tostring ( args.rank ) .."!", "info" )
								self:AddMessage ( clan, "log", player:GetName ( ) .." changed ".. tostring ( args.name ) .."'s rank to ".. tostring ( args.rank ) .."." )
							else
								player:Message ( "Faction: Unable to set rank, contact an admin.", "err" )
							end
						else
							player:Message  ( "Faction: ".. tostring ( args.name ) .."'s rank is already ".. tostring ( args.rank ) .."!", "err" )
						end
					else
						player:Message ( "Faction: You can't set the rank of a member of the same rank as yours.", "err" )
					end
				else
					player:Message ( "Faction: You can't set the founder's rank.", "err" )
				end
			else
				player:Message ( "Faction: Member not found.", "err" )
			end
		else
			player:Message ( "Faction: You can't use this function.", "err" )
		end
	else
		player:Message ( "Faction: You ain't in a faction.", "err" )
	end
end

function ClanSystem:GetMemberData ( args )
	local clan = self.playerClan [ args.steamID ]
	if ( clan ) then
		local clanName = clan [ 1 ]
		local index = clan [ 2 ]
		local members = self.clanMembers [ clanName ]
		if ( members ) then
			local member = members [ index ]
			if ( type ( member ) == "table" ) then
				return member [ args.data ]
			else
				return false
			end
		else
			return false
		end
	else
		return false
	end
end

function ClanSystem:SetMemberData ( args )
	local clan = self.playerClan [ args.steamID ]
	if ( clan ) then
		local clanName = clan [ 1 ]
		local index = clan [ 2 ]
		local members = self.clanMembers [ clanName ]
		if ( members ) then
			local member = members [ index ]
			if ( type ( member ) == "table" ) then
				self.clanMembers [ clanName ] [ index ] [ args.data ] = args.value
				local transaction = SQL:Transaction ( )
				local query = SQL:Command ( "UPDATE clan_members SET ".. tostring ( args.data ) .." = ? WHERE clan = ? and steamID = ?" )
				query:Bind ( 1, args.value )
				query:Bind ( 2, clanName )
				query:Bind ( 3, args.steamID )
				query:Execute ( )
				transaction:Commit ( )

				return true
			else
				return false
			end
		else
			return false
		end
	else
		return false
	end
end

function ClanSystem:IsPlayerAllowedTo ( args )
	local clan = self:GetPlayerClan ( args.player )
	if ( clan ) then
		local rank = self:GetMemberData ( { steamID = args.player:GetSteamId ( ).id, data = "rank" } )
		if ( rank ) then
			return self.permissions [ rank ] [ args.action ]
		else
			return false
		end
	else
		return false
	end
end

function Player:Message ( msg, color )
	self:SendChatMessage ( msg, msgColors [ color ] )
end

function ClanSystem:AddMessage ( clan, type, msg )
	if self:Exists ( clan ) then
		local cmd = SQL:Command ( "INSERT INTO clan_messages ( clan, type, message, date ) VALUES ( ?, ?, ?, ? )" )
		cmd:Bind ( 1, clan )
		cmd:Bind ( 2, type )
		cmd:Bind ( 3, msg )
		cmd:Bind ( 4, os.date ( "%c" ) )
		cmd:Execute ( )
		if ( not self.clanMessages [ clan ] ) then
			self.clanMessages [ clan ] = { }
		end
		table.insert (
			self.clanMessages [ clan ],
			{
				clan = clan,
				type = type,
				message = msg
			}
		)
	end
end

function ClanSystem:FactionChat ( args )
    local msg = args.text
    if ( msg:sub ( 1, 1 ) ~= "/" ) then
        return true
    end

    local msg = msg:sub ( 2 )
    local cmd_args = msg:split ( " " )
    local cmd_name = cmd_args [ 1 ]:lower ( )
	if ( cmd_name == "f" ) then
		table.remove ( cmd_args, 1 )
		local clan = self:GetPlayerClan ( args.player )
		if ( clan ) then
			local pName = args.player:GetName ( )
			local colour = ( self.clans [ clan ].colour:split ( "," ) or { 255, 255, 255 } )
			local r, g, b = table.unpack ( colour )
			for player in Server:GetPlayers ( ) do
				local pClan = self:GetPlayerClan ( player )
				if ( pClan ) then
					if ( pClan == clan ) then
						player:SendChatMessage ( "(Faction Chat) ".. tostring ( pName ) ..": ".. tostring ( table.concat ( cmd_args, " ") ), Color ( tonumber ( r ), tonumber ( g ), tonumber ( b ) ) )
					end
				end
			end
		end
	end
end

function ClanSystem:UpdateMOTD ( text, player )
	local clan = self:GetPlayerClan ( player )
	if ( clan ) then
		if self:IsPlayerAllowedTo ( { player = player, action = "setMotd" } ) then
			local transaction = SQL:Transaction ( )
			local query = SQL:Command ( "UPDATE clans SET motd = ? WHERE name = ?" )
			query:Bind ( 1, text )
			query:Bind ( 2, clan )
			query:Execute ( )
			transaction:Commit ( )
			self:SetClanData ( clan, "motd", text )
			player:Message ( "Faction: MOTD successfully updated.", "info" )
			self:AddMessage ( clan, "log", player:GetName ( ) .." updated the faction MOTD." )
		else
			player:Message ( "Faction: You can't use this function.", "err" )
		end
	else
		player:Message ( "Faction: You ain't in a faction.", "err" )
	end
end

function ClanSystem:ClearLog ( _, player )
	local clan = self:GetPlayerClan ( player )
	if ( clan ) then
		if self:IsPlayerAllowedTo ( { player = player, action = "clearLog" } ) then
			local cmd = SQL:Command ( "DELETE FROM clan_messages WHERE clan = ( ? )" )
			cmd:Bind ( 1, clan )
			cmd:Execute ( )
			self.clanMessages [ clan ] = { }
			player:Message ( "Faction: Log successfully cleared.", "info" )
			self:AddMessage ( clan, "log", player:GetName ( ) .." cleared the faction log." )
		else
			player:Message ( "Faction: You can't use this function.", "err" )
		end
	else
		player:Message ( "Faction: You ain't in a faction.", "err" )
	end
end

clanSystem = ClanSystem ( )

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
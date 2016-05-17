--========= Copyright © 2013-2016, Planimeter, All rights reserved. ==========--
--
-- Purpose: Console class
--
--============================================================================--

-- UNDONE: The gui subsystem will load gui.console again here just by indexing
-- it the first time around, so we can't persist commandHistory in debug
-- local commandHistory = gui.console and gui.console.commandHistory or {}

require( "engine.client.gui.console.consoletextbox" )
require( "engine.client.gui.console.consoletextboxautocompleteitemgroup" )

class "console" ( gui.frame )

function console.print( ... )
	local args = { ... }
	for i = 1, select( "#", ... ) do
		args[ i ] = tostring( args[ i ] )
	end
	g_Console.output:insertText( table.concat( args, "\t" ) .. "\n" )
end

local function doCommand( self, input )
	self.input:setText( "" )
	print( "] " .. input )

	local command = string.match( input, "^([^%s]+)" )
	if ( not command ) then
		return
	end

	local _, endPos = string.find( input, command, 1, true )
	local argString = string.trim( string.utf8sub( input, endPos + 1 ) )
	local argTable  = string.parseargs( argString )
	if ( concommand.getConcommand( command ) ) then
		concommand.dispatch( localplayer, command, argString, argTable )
	elseif ( convar.getConvar( command ) ) then
		if ( argString ~= "" ) then
			if ( string.utf8sub( argString, 1, 1 )   == "\"" and
			     string.utf8sub( argString, -1, -1 ) == "\"" ) then
				argString = string.utf8sub( argString, 2, -2 )
			end
			convar.setConvar( command, argString )
		else
			local convar     = convar.getConvar( command )
			local helpString = convar:getHelpString()
			local default    = convar:getDefault()
			print( convar:getName() .. " = \"" .. convar:getValue() .. "\" " ..
			     ( default    ~= nil and "(Default: \"" .. default .. "\")\n" or "" ) ..
			     ( helpString ~= nil and helpString                           or "" ) )
		end
	else
		print( "'" .. command .. "' is not recognized as a console command " ..
		       "or variable." )
	end
end

-- console.commandHistory = commandHistory
console.commandHistory = {}

local function autocomplete( text )
	if ( text == "" ) then
		return nil
	end

	local suggestions = {}

	for command in pairs( concommand.concommands ) do
		if ( string.find( command, text, 1, true ) == 1 and
		     not table.hasvalue( gui.console.commandHistory, command ) ) then
			table.insert( suggestions, command .. " " )
		end
	end

	for command, convar in pairs( convar.convars ) do
		if ( string.find( command, text, 1, true ) == 1 ) then
			table.insert( suggestions, command .. " " .. convar:getValue() )
		end
	end

	table.sort( suggestions )

	for i, history in ipairs( gui.console.commandHistory ) do
		if ( string.find( history, text, 1, true ) == 1 ) then
			table.insert( suggestions, 1, history )
		end
	end

	local name = string.match( text, "^([^%s]+)" )
	if ( name ) then
		local shouldAutocomplete = string.find( text, name .. " ", 1, true )
		if ( shouldAutocomplete ) then
			local command = concommand.getConcommand( name )
			if ( command ) then
				local _, endPos = string.find( text, name, 1, true )
				local argString = string.trim( string.utf8sub( text, endPos + 1 ) )
				local argTable  = string.parseargs( argString )
				local autocomplete = command:getAutocomplete( argString, argTable )
				if ( autocomplete ) then
					local t = autocomplete( argString, argTable )
					if ( t ) then
						table.prepend( suggestions, t )
					end
				end
			end
		end
	end

	return #suggestions > 0 and suggestions or nil
end

function console:console()
	local name = "Console"
	gui.frame.frame( self, g_MainMenu or g_RootPanel, name, "Console" )
	self.width     = 661
	self.minHeight = 178

	self.output = gui.consoletextbox( self, name .. " Output Text Box", "" )
	self.input  = gui.textbox( self, name .. " Input Text Box", "" )
	self.input.onEnter = function( textbox, text )
		text = string.trim( text )
		doCommand( self, text )

		local commandHistory = gui.console.commandHistory
		if ( not table.hasvalue( commandHistory, text ) and text ~= "" ) then
			table.insert( commandHistory, text )
		end
	end

	if ( not _INTERACTIVE ) then
		self.input:setAutocomplete( autocomplete )
		name = name .. " Autocomplete Item Group"
		self.input.autocompleteItemGroup = gui.consoletextboxautocompleteitemgroup( self.input, name )
		self.input.autocompleteItemGroup.keypressed = function( autocompleteItemGroup, key, isrepeat )
			if ( key ~= "delete" ) then
				return
			end

			-- BUGBUG: We never get here anymore due to the introduction of
			-- cascadeInputToChildren.
			for i, history in ipairs( gui.console.commandHistory ) do
				if ( autocompleteItemGroup:getValue() == history ) then
					table.remove( gui.console.commandHistory, i )
					local item = autocompleteItemGroup:getSelectedItem()
					autocompleteItemGroup:removeItem( item )
					return
				end
			end
		end
	end

	self:invalidateLayout()

	if ( _INTERACTIVE ) then
		self:doModal()
	end
end

function console:activate()
	self:invalidate()
	gui.frame.activate( self )
	gui.setFocusedPanel( self.input, true )
end

function console:drawBackground()
	if ( _INTERACTIVE ) then
		return
	end

	gui.frame.drawBackground( self )
end

function console:invalidateLayout()
	if ( not self:isResizing() ) then
		local parent = self:getParent()
		local margin = gui.scale( 36 )
		if ( not _INTERACTIVE ) then
			self:setPos( parent:getWidth() - self:getWidth() - margin, margin )
		else
			self:setPos( 0, 0 )
		end
	end

	self.output:setPos( 36, 87 )
	self.output:setWidth( self:getWidth() - 2 * 36 )
	self.input:setPos( 36, self:getHeight() - self.input:getHeight() - 36 )
	self.input:setWidth( self:getWidth() - 2 * 36 )
	gui.frame.invalidateLayout( self )
end

gui.register( console, "console" )

local con_enable = convar( "con_enable", "0", nil, nil,
                           "Allows the console to be activated" )

concommand( "toggleconsole", "Show/hide the console", function()
	local mainmenu = g_MainMenu
	local console  = g_Console
	if ( not mainmenu:isVisible() and
	         console:isVisible()  and
	         con_enable:getBoolean() ) then
		mainmenu:activate()
		console:activate()
		return
	end

	if ( console:isVisible() ) then
		console:close()
	else
		if ( not con_enable:getBoolean() ) then
			return
		end

		if ( not mainmenu:isVisible() ) then
			mainmenu:activate()
		end

		console:activate()
	end
end )

concommand( "clear", "Clears the console", function()
	if ( _WINDOWS ) then
		-- This breaks the LOVE console. :(
		-- os.execute( "cls" )
	else
		os.execute( "clear" )
	end

	if ( g_Console ) then
		g_Console.output:setText( "" )
	end
end )

concommand( "echo", "Echos text to console",
	function( _, _, _, argS, argT )
		print( argS )
	end
)

concommand( "help", "Prints help info for the console command or variable",
	function( _, _, _, _, argT )
		local name = argT[ 1 ]
		if ( name == nil ) then
			print( "help <console command or variable name>" )
			return
		end

		local command = concommand.getConcommand( name ) or
		                convar.getConvar( name )
		if ( command ) then
			print( command:getHelpString() )
		else
			print( "'" .. name .. "' is not a valid console command or " ..
			       "variable." )
		end
	end
)

if ( g_Console ) then
	local visible = g_Console:isVisible()
	local output  = g_Console.output:getText()
	g_Console:remove()
	g_Console = nil
	g_Console = gui.console()
	g_Console.output:setText( output )
	if ( visible ) then
		g_Console:activate()
	end
end

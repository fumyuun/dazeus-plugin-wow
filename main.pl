#!/usr/bin/perl

# DaZeus WoW plugin - a World of Warcraft API plugin for DaZeus
# Plugin copyright (C) 2012 Koray Yanik <fumyuun@gmail.com>
# Built on DaZeus ( https://github.com/dazeus/dazeus ) and WoW::Armory::API
# See LICENSE for license.

use strict;
use warnings;

use DaZeus;
use WoW::Armory::API;

use Data::Dumper;
use feature 'say';

# Basic strings so we dont have to query the api server every time about these.
my @classes = ("?", "Warrior", "Paladin", "Hunter", "Rogue", "Priest", "Death Knight", "Shaman", "Mage", "Warlock", "Monk", "Druid", "?");
my @races = ("?", "Human", "Orc", "Dwarf", "Night Elf", "Undead", "Tauren", "Gnome", "Troll", "Goblin", "Blood Elf", "Draenei", "?", "?", "?", "?", "?", "?", "?", "?", "?", "?", "Worgen", "?", "Pandaren(N)", "Pandaren(A)", "Pandaren(H)", "?");

# Start plugin
my ($socket, $network) = @ARGV;
if(!$network) {
	die "Usage: $0 socket network\n";
}
my $dazeus = DaZeus->connect($socket);
$dazeus->subscribe("PRIVMSG", \&message);
my $wow_api = WoW::Armory::API->new(Region => 'eu', Locale => 'en_GB');
while($dazeus->handleEvents()){}
die "Quit!";

# Message handler subroutine
sub message
{
    my (undef, $event) = @_;
    my $netw = $event->{params}[0];
    my $nick = $event->{params}[1];
    my $chan = $event->{params}[2];
    my $mesg = $event->{params}[3];
    
    my @cmd = split(/ /, $mesg);
    if($cmd[0] eq "}wow")
    {
        if(@cmd == 2 && $cmd[1] eq "help"){
            print_help("full", $chan, @cmd);
        }
        elsif(@cmd == 4 && $cmd[1] eq "query"){
            query_charinfo($chan, $cmd[2], $cmd[3]);
        }
        elsif(@cmd == 4 && $cmd[1] eq "register"){
            register_char($chan, $nick, $cmd[2], $cmd[3]);
        }
        elsif(@cmd == 4 && $cmd[1] eq "unregister"){
            unregister_char($chan, $nick, $cmd[2], $cmd[3]);
        }
        elsif(@cmd == 2 && $cmd[1] eq "list"){
            list_chars($chan, $nick);
        }
        else {
            print_help("min", $chan, @cmd);
        }
    }
}

# print_help(string, channel, (commands))
# prints help depending on parameters. Prints small info if string is not
# equal to "full".
sub print_help
{
    my ($full, $chan, @params) = @_;
    if(@params == 3)
    {
        if($params[2] eq "register"){
            $dazeus->message($network, $chan, "register <realm> <character> : Register a character on a realm to your current nick.");
            return;
        }
        if($params[2] eq "unregister"){
            $dazeus->message($network, $chan, "unregister <realm> <character> : Unregister a character on a realm to your current nick.");
            return;
        }
        elsif($params[2] eq "query"){
            $dazeus->message($network, $chan, "query <realm> <character> : Query basic character info. Note that realm name must be lower case and spaces have to be replaced by coloms (-).");
            return;
        }
        elsif($params[2] eq "list"){
            $dazeus->message($network, $chan, "list : List all my registered characters.");
            return;
        }
    }
    if($full eq "full") {
        $dazeus->message($network, $chan, "Possible commands are help, register, unregister, query and list. Type }help <command> for more info about a certain command.");
    }
    else {
        $dazeus->message($network, $chan, "Type }wow help for usage info.");
    }
}

# query_charinfo(channel, realm, character)
# query and display basic character info.
sub query_charinfo
{
    my ($chan, $realm, $char) = @_;
    print "Query of " . $realm . " - " . $char . "\n";
    my $char_data = $wow_api->GetCharacter($realm, $char, 'feed');
    
    if($char_data->{status} && $char_data->{status} eq "nok") {
        $dazeus->message($network, $chan, "Query failed: " . $char_data->{reason});
        return;
    }
    
    $dazeus->message($network, $chan, "[" . $char_data->{level} . "] "
    . $char_data->{name} .
    " - " . @races[$char_data->{race}] . " "
    . @classes[$char_data->{class}] .
    " - (" . $char_data->{realm} . ")");
}

# register_char(channel, nick, realm, char)
# Attempts to register a given character on a realm to a nick. 
sub register_char
{
    my ($chan, $nick, $realm, $char) = @_;
    $char = lc $char;
    
    print "Register attempt " . $realm . " - " . $char . " by " . $nick . ": ";
    
    my $char_data = $wow_api->GetCharacter($realm, $char);
    if($char_data->{status} && $char_data->{status} eq "nok") {
        $dazeus->message($network, $chan, "Registring failed: " . $char_data->{reason});
        print "invalid query\n";
        return;
    }
    
    my $key = $realm . "." . $char;
    my $regchars = $dazeus->getProperty("plugins.wow.charlist");
    if(!$regchars) {
        $regchars = {$key => $nick};
        print "creating new property plugins.wow.charlist... ";
    }
    else {
        if(exists($regchars->{$key})) {
            $dazeus->message($network, $chan, "This character is already registered to " . $regchars->{$key} . "!");
            print "invalid (owner: " . $regchars->{$key} . ")\n";
            return;
        }
        else {
            $regchars->{$key} = $nick;
            print "ok\n";
        }
    }
    $dazeus->setProperty("plugins.wow.charlist", $regchars);
    $dazeus->message($network, $chan, "Character succesfully registered!");
}

# unregister_char(channel, nick, realm, char)
# Attempts to unregister a given character on a realm, if it's owned by nick.
sub unregister_char
{
    my ($chan, $nick, $realm, $char) = @_;
    $char = lc $char;
    $realm = lc $realm;
    
    print "Unregister attempt " . $realm . " - " . $char . " by " . $nick . ": ";
    
    my $char_data = $wow_api->GetCharacter($realm, $char);
    if($char_data->{status} && $char_data->{status} eq "nok") {
        $dazeus->message($network, $chan, "Unregistring failed: " . $char_data->{reason});
        print "invalid query\n";
        return;
    }
    
    my $key = $realm . "." . $char;
    my $regchars = $dazeus->getProperty("plugins.wow.charlist");
    if(!$regchars) {
        $dazeus->message($network, $chan, "But there are no characters registered!");
        print "invalid (no properties)\n";
        return;
    }
    else {
        if(exists($regchars->{$key})) {
            if($regchars->{$key} eq $nick) {
                delete $regchars->{$key};
                print "ok\n";
            }
            else {
                $dazeus->message($network, $chan, "But this character isn't yours!");
                print "invalid (owner: " . $regchars->{$key} . ")\n";
                return;
            }
        }
        else {
            $dazeus->message($network, $chan, "But this character isn't registered!");
            print "invalid (doesn't exist)\n";
            return;
        }
    }
    $dazeus->setProperty("plugins.wow.charlist", $regchars);
    $dazeus->message($network, $chan, "Character succesfully unregistered!");
}

# list_chars(chan, nick)
# Query and list all characters registered to a given nick.
sub list_chars
{
    my ($chan, $nick) = @_;
    
    print "List chars by " . $nick . ": ";
    
    my $regchars = $dazeus->getProperty("plugins.wow.charlist");
    if(!$regchars) {
        $dazeus->message($network, $chan, "But there are no characters registered!");
        print "invalid (no properties)\n";
        return;
    }
    
    for(keys %$regchars)
    {
        if($regchars->{$_} eq $nick)
        {
            print $_ . " ";
            my @subs = split(/\./, $_);
            if(@subs != 2) {
                die "Database inconsistency!\n";
            }
            query_charinfo($chan, $subs[0], $subs[1]);
        }
    }
    print "\n";
}
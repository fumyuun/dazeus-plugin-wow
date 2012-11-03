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
poll_feeds();
my $last_poll = time();
while(1) {
    while($dazeus->handleEvent(5)) {}
    if(time() - $last_poll > 60) {
        poll_feeds();
        $last_poll = time();
    }
}
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
        elsif(@cmd == 3 && $cmd[1] eq "list"){
            list_chars($chan, $cmd[2]);
        }
        elsif(@cmd == 2 && $cmd[1] eq "subscribe"){
            toggle_feeds($chan, "on");
        }
        elsif(@cmd == 2 && $cmd[1] eq "unsubscribe"){
            toggle_feeds($chan, "off");
        }
        elsif(@cmd == 2 && $cmd[1] eq "queryfeeds"){
            my $cmap = {$chan => 1};
            query_feeds($cmap);
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
            $dazeus->message($network, $chan, "query <realm> <character> : Query basic character info. Note that realm name must be lower case and spaces have to be replaced by dashes (-).");
            return;
        }
        elsif($params[2] eq "list"){
            $dazeus->message($network, $chan, "list [nickname] : List all registered characters of nickname (or yourself if nickname is not given).");
            return;
        }
        if($params[2] eq "subscribe"){
            $dazeus->message($network, $chan, "subscribe : Subscribes the current channel to feed updates.");
            return;
        }
        if($params[2] eq "unsubscribe"){
            $dazeus->message($network, $chan, "unsubscribe : Unsubscribes the current channel from feed updates.");
            return;
        }
    }
    if($full eq "full") {
        $dazeus->message($network, $chan, "Possible commands are help, register, unregister, subscribe, unsubscribe, query and list. Type }wow help <command> for more info about a certain command.");
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
    my $char_data = $wow_api->GetCharacter($realm, $char);
    
    if(!$char_data) {
        $dazeus->message($network, $chan, "Query failed?");
        return;
    }
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
    $realm = lc $realm;
    
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
    
    print "List chars by " . $nick . ":\n";
    
    my $regchars = $dazeus->getProperty("plugins.wow.charlist");
    if(!$regchars) {
        $dazeus->message($network, $chan, "But there are no characters registered!");
        print "invalid (no properties)\n";
        return;
    }
    
    my $counter = 0;
    for(keys %$regchars)
    {
        if($regchars->{$_} eq $nick){
            print "\t";
            my @subs = split(/\./, $_);
            if(@subs != 2){
                die "Database inconsistency!\n";
            }
            query_charinfo($chan, $subs[0], $subs[1]);
            $counter++;
        }
    }
    if($counter == 0){
        $dazeus->message($network, $chan, "But you don't have any registered characters!");
    }
}

# poll_feeds()
# Poll all registered feeds to all subscribed channels.
sub poll_feeds
{
    my $subs = $dazeus->getProperty("plugins.wow.subscribers");
    print "Poll feeds.\n";
    query_feeds($subs);
}

# query_feeds(channels)
# Query feeds of all registered characters and displays changes in the
# given channels (in the form of a hashmap with channels as keys.).
sub query_feeds
{
    my ($chan, undef) = @_;
    print scalar(localtime(time())) . " ** Query feeds to " . Dumper($chan) . "\n";
    
    my $regchars = $dazeus->getProperty("plugins.wow.charlist");
    if(!$regchars) {
        return;
    }
    
    for(keys %$regchars)
    {
        print "\tQuery " . $_ . ": ";
        
        my @subs = split(/\./, $_);
        if(@subs != 2) {
            die "Database inconsistency!\n";
        }
        
        my $new_feed = $wow_api->GetCharacter($subs[0], $subs[1], 'feed');
        if(!$new_feed) {
            print "Query failed?\n";
            next;
        }
        if($new_feed->{status} && $new_feed->{status} eq "nok") {
            print "Query failed: " . $new_feed->{reason};
            next;
        }
        if(!$new_feed->{lastModified} || !$new_feed->{level}) {
            print "Query failed?\n";
            next;
        }
        
        print "tnew: " . $new_feed->{lastModified} . " ";
        
        my $old_timestamp = $dazeus->getProperty("plugins.wow.charfeed." . $_ . ".timestamp");
        my $old_level = $dazeus->getProperty("plugins.wow.charfeed." . $_ . ".level");
        if(!$old_timestamp || !$old_level) {
            print "store.\n";
            $dazeus->setProperty("plugins.wow.charfeed." . $_ . ".timestamp", $new_feed->{lastModified});
            $dazeus->setProperty("plugins.wow.charfeed." . $_ . ".level", $new_feed->{level});
            next;
        }
        print "told: " . $old_timestamp . " ";
        
        if($old_timestamp != $new_feed->{lastModified}) {
            print "update.\n";
            parse_fdiff($chan, $old_timestamp, $old_level, $new_feed);
            $dazeus->setProperty("plugins.wow.charfeed." . $_ . ".timestamp", $new_feed->{lastModified});
            $dazeus->setProperty("plugins.wow.charfeed." . $_ . ".level", $new_feed->{level});
        }
        else {
            print "same.\n";
        }
    }
}

# parse_fdfiff(channels, old_timestamp, old_level, new_feed)
# Parse difference between last seen and current feed, using the old timestamp
# and level. Will output all changes to the given channels (in the form of
# a hashmap with channels as keys).
sub parse_fdiff
{
    my ($chan, $old_timestamp, $old_level, $new_feed) = @_;
    if($old_level != $new_feed->{level}) {
	for my $channel (keys %$chan) {
        	$dazeus->message($network, $channel, $new_feed->{name} . " (" . $new_feed->{realm} . ") has leveled up to level " . $new_feed->{level} . "! \\o/");
	}
    }
    my $item;
    foreach $item (reverse @{$new_feed->{feed}})
    {
        if($item->{timestamp} > $old_timestamp) {
            if($item->{type} eq "ACHIEVEMENT") {
                for my $channel (keys %$chan) {
                    $dazeus->message($network, $channel, $new_feed->{name} . " (" . $new_feed->{realm} . ") has gained [" . $item->{achievement}{title} . "]! \\o/");
                }
            }
            elsif($item->{type} eq "LOOT") {
                my $itemdat = $wow_api->GetItem($item->{itemId});
                for my $channel (keys %$chan) {
                    $dazeus->message($network, $channel, $new_feed->{name} . " (" . $new_feed->{realm} . ") has looted " . $itemdat->{name} . "! \\o/");
                }
            }
            elsif($item->{type} eq "BOSSKILL") {
                for my $channel (keys %$chan) {
                    $dazeus->message($network, $channel, $new_feed->{name} . " (" . $new_feed->{realm} . ") has cleared " . $item->{name} . "! \\o/");
                }
            }
        }
    }
}

# toggle_feed(channel, "on"/"off")
# Subscribe or unsubscribe a channel from feeds.
sub toggle_feeds
{
    my ($chan, $flag) = @_;
    print "Setting feed subscription for " . $chan . " to " . $flag . "\n";
    
    my $subs = $dazeus->getProperty("plugins.wow.subscribers");
    if(!$subs){
        $subs = {};
    }
    
    if($flag eq "on"){
        if(exists($subs->{$chan})){
            $dazeus->message($network, $chan, "But this channel is already subscribed!");
            return;
        }
        else {
            $subs->{$chan} = 1;
            $dazeus->message($network, $chan, "I will subscribe this channel.");
        }
    }
    elsif($flag eq "off"){
        if(exists($subs->{$chan})){
            delete $subs->{$chan};
            $dazeus->message($network, $chan, "I will unsubscribe this channel.");
        }
        else {
            $dazeus->message($network, $chan, "But this channel is not subscribed!");
            return;
        }
    }
    
    $dazeus->setProperty("plugins.wow.subscribers", $subs);
}

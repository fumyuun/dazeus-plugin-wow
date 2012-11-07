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

# Max retries before giving up a query
my $MAX_RETRIES = 3;
# Time inbetween polls (seconds).
my $POLL_TIME_S = 60;

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
poll_feeds($network);
my $last_poll = time();
while(1) {
    while($dazeus->handleEvent(5)) {}
    if(time() - $last_poll > $POLL_TIME_S) {
        poll_feeds($network);
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
            print_help("full", $netw, $chan, @cmd);
        }
        elsif(@cmd == 4 && $cmd[1] eq "query"){
            query_charinfo($netw, $chan, $cmd[2], $cmd[3]);
        }
        elsif(@cmd == 4 && $cmd[1] eq "gquery"){
            query_guildinfo($netw, $chan, $cmd[2], $cmd[3]);
        }
        elsif(@cmd == 4 && $cmd[1] eq "register"){
            register_char($netw, $chan, $nick, $cmd[2], $cmd[3]);
        }
        elsif(@cmd == 4 && $cmd[1] eq "unregister"){
            unregister_char($netw, $chan, $nick, $cmd[2], $cmd[3]);
        }
        elsif(@cmd == 4 && $cmd[1] eq "gregister"){
            register_guild($netw, $chan, $nick, $cmd[2], $cmd[3]);
        }
        elsif(@cmd == 4 && $cmd[1] eq "gunregister"){
            unregister_guild($netw, $chan, $nick, $cmd[2], $cmd[3]);
        }
        elsif(@cmd == 2 && $cmd[1] eq "list"){
            list_chars($netw, $chan, $nick);
        }
        elsif(@cmd == 3 && $cmd[1] eq "list"){
            list_chars($netw, $chan, $cmd[2]);
        }
        elsif(@cmd == 2 && $cmd[1] eq "glist"){
            list_guilds($netw, $chan, $nick);
        }
        elsif(@cmd == 3 && $cmd[1] eq "glist"){
            list_guilds($netw, $chan, $cmd[2]);
        }
        elsif(@cmd == 2 && $cmd[1] eq "list-all"){
            list_allchars($netw, $chan);
        }
        elsif(@cmd == 2 && $cmd[1] eq "glist-all"){
            list_allguilds($netw, $chan);
        }
        elsif(@cmd == 2 && $cmd[1] eq "subscribe"){
            toggle_feeds($netw, $chan, "on");
        }
        elsif(@cmd == 2 && $cmd[1] eq "unsubscribe"){
            toggle_feeds($netw, $chan, "off");
        }
        elsif(@cmd == 2 && $cmd[1] eq "queryfeeds"){
            poll_feeds($netw);
        }
        else {
            print_help("min", $netw, $chan, @cmd);
        }
    }
}

# print_help(string, channel, (commands))
# prints help depending on parameters. Prints small info if string is not
# equal to "full".
sub print_help
{
    my ($full, $netw, $chan, @params) = @_;
    if(@params == 3)
    {
        if($params[2] eq "register"){
            $dazeus->message($netw, $chan, "register <realm> <character> : Register a character on a realm to your current nick.");
            return;
        }
        if($params[2] eq "unregister"){
            $dazeus->message($netw, $chan, "unregister <realm> <character> : Unregister a character on a realm to your current nick.");
            return;
        }
        if($params[2] eq "gregister"){
            $dazeus->message($netw, $chan, "register <realm> <guild> : Register a guild on a realm to your current nick.");
            return;
        }
        if($params[2] eq "gunregister"){
            $dazeus->message($netw, $chan, "unregister <realm> <guild> : Unregister a guild on a realm to your current nick.");
            return;
        }
        elsif($params[2] eq "query"){
            $dazeus->message($netw, $chan, "query <realm> <character> : Query basic character info. Note that all spaces have to be replaced by dashes (-).");
            return;
        }
        elsif($params[2] eq "gquery"){
            $dazeus->message($netw, $chan, "query <realm> <guild> : Query basic guild info. Note that all spaces have to be replaced by dashes (-).");
            return;
        }
        elsif($params[2] eq "list"){
            $dazeus->message($netw, $chan, "list [nickname] : List all registered characters of nickname (or yourself if nickname is not given).");
            return;
        }
        elsif($params[2] eq "list-all"){
            $dazeus->message($netw, $chan, "list-all : List all registered characters.");
            return;
        }
        elsif($params[2] eq "glist"){
            $dazeus->message($netw, $chan, "list [nickname] : List all registered guilds of nickname (or yourself if nickname is not given).");
            return;
        }
        elsif($params[2] eq "glist-all"){
            $dazeus->message($netw, $chan, "glist-all : List all registered guilds.");
            return;
        }
        if($params[2] eq "subscribe"){
            $dazeus->message($netw, $chan, "subscribe : Subscribes the current channel to feed updates.");
            return;
        }
        if($params[2] eq "unsubscribe"){
            $dazeus->message($netw, $chan, "unsubscribe : Unsubscribes the current channel from feed updates.");
            return;
        }
    }
    if($full eq "full") {
        $dazeus->message($netw, $chan, "Possible commands are help, register, unregister, gregister, gunregister, subscribe, unsubscribe, query, gquery, list, list-all, glist and glist-all. Type }wow help <command> for more info about a certain command. Character, realm and guildnames are case insensitive, while nicknames are.");
    }
    else {
        $dazeus->message($netw, $chan, "Type }wow help for usage info.");
    }
}

# query_charinfo(network, channel, realm, character, owner)
# query and display basic character info. Owner is optional.
sub query_charinfo
{
    my ($netw, $chan, $realm, $char, $nick) = @_;
    $char = lc $char;
    $realm = lc $realm;
    if($nick){
        $nick =~ s/^(.)(.)/$1~$2/;
    }
    
    print "Query of " . $realm . "." . $char . "\n";
    my $char_data = $wow_api->GetCharacter($realm, $char);
    # Querying sometimes mysteriously fails, try again.
    my $retries;
    for($retries = 0; !$char_data && $retries < $MAX_RETRIES; $retries++) {
        print "Retry (" . $retries . "), ";
        $char_data = $wow_api->GetCharacter($realm, $char);
    }
    if($retries == $MAX_RETRIES && !$char_data) {
        print "Failed...\n";
        return;
    }
    
    if($char_data->{status} && $char_data->{status} eq "nok") {
        $dazeus->message($netw, $chan, "Query failed: " . $char_data->{reason});
        return;
    }
    
    my $output =
    "[" . $char_data->{level} . "] "
    . $char_data->{name} .
    " " . @races[$char_data->{race}] . " "
    . @classes[$char_data->{class}] .
    " (" . $char_data->{realm} . ")";
    
    if($nick) {
        $output = $output . " <" . $nick . ">";
    }
    $dazeus->message($netw, $chan, $output);
}

# query_guildinfo(network, channel, realm, guild)
# query and display basic guild info.
sub query_guildinfo
{
    my ($netw, $chan, $realm, $guild) = @_;
    $guild =~ s/-/ /g;
    $guild = lc $guild;
    $realm = lc $realm;
    
    print "Query of guild " . $realm . "." . $guild . "\n";
    my $guild_data = $wow_api->GetGuild($realm, $guild);
    # Querying sometimes mysteriously fails, try again.
    my $retries;
    for($retries = 0; !$guild_data && $retries < $MAX_RETRIES; $retries++) {
        print "Retry (" . $retries . "), ";
        $guild_data = $wow_api->GetGuild($realm, $guild);
    }
    if($retries == $MAX_RETRIES && !$guild_data) {
        print "Failed...\n";
        return;
    }
    
    if($guild_data->{status} && $guild_data->{status} eq "nok") {
        $dazeus->message($netw, $chan, "Query failed: " . $guild_data->{reason});
        return;
    }
    
    $dazeus->message($netw, $chan, "[" . $guild_data->{level} . "] "
    . $guild_data->{name} . " (" . ($guild_data->{side} == 0 ? "A" : "H") . ")");
}

# register_char(network, channel, nick, realm, char)
# Attempts to register a given character on a realm to a nick. 
sub register_char
{
    my ($netw, $chan, $nick, $realm, $char) = @_;
    $char = lc $char;
    $realm = lc $realm;
    
    print "Register attempt " . $realm . "." . $char . " by " . $nick . ": ";
    
    my $char_data = $wow_api->GetCharacter($realm, $char);
    # Querying sometimes mysteriously fails, try again.
    my $retries;
    for($retries = 0; !$char_data && $retries < $MAX_RETRIES; $retries++) {
        print "Retry (" . $retries . "), ";
        $char_data = $wow_api->GetCharacter($realm, $char);
    }
    if($retries == $MAX_RETRIES && !$char_data) {
        print "Failed...\n";
        return;
    }
    
    if($char_data->{status} && $char_data->{status} eq "nok") {
        $dazeus->message($netw, $chan, "Registring failed: " . $char_data->{reason});
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
            $dazeus->message($netw, $chan, "This character is already registered to " . $regchars->{$key} . "!");
            print "invalid (owner: " . $regchars->{$key} . ")\n";
            return;
        }
        else {
            $regchars->{$key} = $nick;
            print "ok\n";
        }
    }
    $dazeus->setProperty("plugins.wow.charlist", $regchars);
    $dazeus->message($netw, $chan, "Character succesfully registered!");
}

# unregister_char(network, channel, nick, realm, char)
# Attempts to unregister a given character on a realm, if it's owned by nick.
sub unregister_char
{
    my ($netw, $chan, $nick, $realm, $char) = @_;
    $char = lc $char;
    $realm = lc $realm;
    
    print "Unregister attempt " . $realm . "." . $char . " by " . $nick . ": ";
    
    my $key = $realm . "." . $char;
    my $regchars = $dazeus->getProperty("plugins.wow.charlist");
    if(!$regchars) {
        $dazeus->message($netw, $chan, "But there are no characters registered!");
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
                $dazeus->message($netw, $chan, "But this character isn't yours!");
                print "invalid (owner: " . $regchars->{$key} . ")\n";
                return;
            }
        }
        else {
            $dazeus->message($netw, $chan, "But this character isn't registered!");
            print "invalid (doesn't exist)\n";
            return;
        }
    }
    $dazeus->setProperty("plugins.wow.charlist", $regchars);
    $dazeus->message($netw, $chan, "Character succesfully unregistered!");
}

# register_guild(network, channel, nick, realm, guild)
# Attempts to register a given guild on a realm to a nick.
# Encode spaces in guildnames with dashes (-).
sub register_guild
{
    my ($netw, $chan, $nick, $realm, $guild) = @_;
    $guild =~ s/-/ /g;
    $guild = lc $guild;
    $realm = lc $realm;
    
    print "Register guild attempt " . $realm . "." . $guild . " by " . $nick . ": ";
    
    my $guild_data = $wow_api->GetGuild($realm, $guild);
    # Querying sometimes mysteriously fails, try again.
    my $retries;
    for($retries = 0; !$guild_data && $retries < $MAX_RETRIES; $retries++) {
        print "Retry (" . $retries . "), ";
        $guild_data = $wow_api->GetGuild($realm, $guild);
    }
    if($retries == $MAX_RETRIES && !$guild_data) {
        print "Failed... \n";
        return;
    }
    
    if($guild_data->{status} && $guild_data->{status} eq "nok") {
        $dazeus->message($netw, $chan, "Registring failed: " . $guild_data->{reason});
        print "invalid query\n";
        return;
    }
    
    my $key = $realm . "." . $guild;
    my $regguilds = $dazeus->getProperty("plugins.wow.guildlist");
    if(!$regguilds) {
        $regguilds = {$key => $nick};
        print "creating new property plugins.wow.guildlist... \n";
    }
    else {
        if(exists($regguilds->{$key})) {
            $dazeus->message($netw, $chan, "This guild is already registered to " . $regguilds->{$key} . "!");
            print "invalid (owner: " . $regguilds->{$key} . ")\n";
            return;
        }
        else {
            $regguilds->{$key} = $nick;
            print "ok\n";
        }
    }
    $dazeus->setProperty("plugins.wow.guildlist", $regguilds);
    $dazeus->message($netw, $chan, "Guild succesfully registered!");
}

# unregister_guild(network, channel, nick, realm, guild)
# Attempts to unregister a given guild on a realm, if it's owned by nick.
# Encode spaces in guildnames with dashes (-).
sub unregister_guild
{
    my ($netw, $chan, $nick, $realm, $guild) = @_;
    $guild =~ s/-/ /g;
    $guild = lc $guild;
    $realm = lc $realm;
    
    print "Unregister guild attempt " . $realm . "." . $guild . " by " . $nick . ": ";
    
    my $key = $realm . "." . $guild;
    my $regguilds = $dazeus->getProperty("plugins.wow.guildlist");
    if(!$regguilds) {
        $dazeus->message($netw, $chan, "But there are no guilds registered!");
        print "invalid (no properties)\n";
        return;
    }
    else {
        if(exists($regguilds->{$key})) {
            if($regguilds->{$key} eq $nick) {
                delete $regguilds->{$key};
                print "ok\n";
            }
            else {
                $dazeus->message($netw, $chan, "But this guild isn't yours!");
                print "invalid (owner: " . $regguilds->{$key} . ")\n";
                return;
            }
        }
        else {
            $dazeus->message($netw, $chan, "But this guild isn't registered!");
            print "invalid (doesn't exist)\n";
            return;
        }
    }
    $dazeus->setProperty("plugins.wow.guildlist", $regguilds);
    $dazeus->message($netw, $chan, "Guild succesfully unregistered!");
}

# list_chars(network, chan, nick)
# Query and list all characters registered to a given nick.
sub list_chars
{
    my ($netw, $chan, $nick) = @_;
    
    print "List chars by " . $nick . ":\n";
    
    my $regchars = $dazeus->getProperty("plugins.wow.charlist");
    if(!$regchars) {
        $dazeus->message($netw, $chan, "But there are no characters registered!");
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
            query_charinfo($netw, $chan, $subs[0], $subs[1], $regchars->{$_});
            $counter++;
        }
    }
    if($counter == 0){
        $dazeus->message($netw, $chan, "But you don't have any registered characters!");
    }
}

# list_allchars(network, chan)
# Query and list all registered characters.
sub list_allchars
{
    my ($netw, $chan) = @_;
    
    print "List all characters:\n";
    
    my $regchars = $dazeus->getProperty("plugins.wow.charlist");
    if(!$regchars) {
        $dazeus->message($netw, $chan, "But there are no characters registered!");
        print "invalid (no properties)\n";
        return;
    }
    
    for(keys %$regchars)
    {
        print "\t";
        my @subs = split(/\./, $_);
        if(@subs != 2){
            die "Database inconsistency!\n";
        }
        query_charinfo($netw, $chan, $subs[0], $subs[1], $regchars->{$_});
    }
}

# list_guilds(network, chan, nick)
# Query and list all guilds registered to a given nick.
sub list_guilds
{
    my ($netw, $chan, $nick) = @_;
    
    print "List guilds by " . $nick . ":\n";
    
    my $regguilds = $dazeus->getProperty("plugins.wow.guildlist");
    if(!$regguilds) {
        $dazeus->message($netw, $chan, "But there are no guilds registered!");
        print "invalid (no properties)\n";
        return;
    }
    
    my $counter = 0;
    for(keys %$regguilds)
    {
        if($regguilds->{$_} eq $nick){
            print "\t";
            my @subs = split(/\./, $_);
            if(@subs != 2){
                die "Database inconsistency!\n";
            }
            query_guildinfo($netw, $chan, $subs[0], $subs[1]);
            $counter++;
        }
    }
    if($counter == 0){
        $dazeus->message($netw, $chan, "But you don't have any registered guilds!");
    }
}


# list_allguilds(network, chan)
# Query and list all registered guilds.
sub list_allguilds
{
    my ($netw, $chan) = @_;
    
    print "List all guilds:\n";
    
    my $regguilds = $dazeus->getProperty("plugins.wow.guildlist");
    if(!$regguilds) {
        $dazeus->message($netw, $chan, "But there are no guilds registered!");
        print "invalid (no properties)\n";
        return;
    }
    
    for(keys %$regguilds)
    {
        print "\t";
        my @subs = split(/\./, $_);
        if(@subs != 2){
            die "Database inconsistency!\n";
        }
        query_guildinfo($netw, $chan, $subs[0], $subs[1]);
    }
}

# poll_feeds($netw)
# Poll all registered feeds to all subscribed channels.
sub poll_feeds
{
    my ($netw) = @_;
    my $subs = $dazeus->getProperty("plugins.wow.subscribers");
    print "Poll feeds.\n";
    query_charfeeds($netw, $subs);
    query_guildfeeds($netw, $subs);
}

# query_charfeeds(network, channels)
# Query feeds of all registered characters and displays changes in the
# given channels (in the form of a hashmap with channels as keys.).
sub query_charfeeds
{
    query_feeds(@_, "char");
}

# query_guildfeeds(network, channels)
# Query feeds of all registered guilds and displays changes in the
# given channels (in the form of a hashmap with channels as keys.).
sub query_guildfeeds
{
    query_feeds(@_, "guild");
}

# query_feeds(network, channels, type)
# Query feeds of all registered characters or guilds and displays changes in the
# given channels (in the form of a hashmap with channels as keys.).
# type should either be char or guild.
sub query_feeds
{
    my ($netw, $chan, $type) = @_;
    print scalar(localtime(time())) . " ** Query " . $type . " feeds to " . Dumper($chan) . "\n";
    
    my $regchars = $dazeus->getProperty("plugins.wow." . $type . "list");
    if(!$regchars) {
        print "plugins.wow." . $type . "list doesnt exist?\n";
        return;
    }
    for(keys %$regchars)
    {
        print "\tQuery " . $_ . ": ";
        
        my @subs = split(/\./, $_);
        if(@subs != 2) {
            die "Database inconsistency!\n";
        }
        
        my $new_feed;
        if($type eq "char") {
            $new_feed = $wow_api->GetCharacter($subs[0], $subs[1], 'feed');
        }
        elsif($type eq "guild") {
            $new_feed = $wow_api->GetGuild($subs[0], $subs[1], 'news');
        }
        # Querying sometimes mysteriously fails, try again.
        my $retries;
        for($retries = 0; !$new_feed && $retries < $MAX_RETRIES; $retries++) {
            print "Retry (" . $retries . "), ";
            if($type eq "char") {
                $new_feed = $wow_api->GetCharacter($subs[0], $subs[1], 'feed');
            }
            elsif($type eq "guild") {
                $new_feed = $wow_api->GetGuild($subs[0], $subs[1], 'news');
            }
        }
        if($retries == $MAX_RETRIES && !$new_feed) {
            print "Failed...\n";
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
        
        my $old_timestamp = $dazeus->getProperty("plugins.wow." . $type . "feed." . $_ . ".timestamp");
        my $old_level = $dazeus->getProperty("plugins.wow." . $type . "feed." . $_ . ".level");
        if(!$old_timestamp || !$old_level) {
            print "store.\n";
            $dazeus->setProperty("plugins.wow." . $type . "feed." . $_ . ".timestamp", $new_feed->{lastModified});
            $dazeus->setProperty("plugins.wow." . $type . "feed." . $_ . ".level", $new_feed->{level});
            next;
        }
        print "told: " . $old_timestamp . " ";
        
        if($old_timestamp != $new_feed->{lastModified}) {
            print "update.\n";
            parse_fdiff($netw, $chan, $old_timestamp, $old_level, $new_feed, $type);
            $dazeus->setProperty("plugins.wow." . $type . "feed." . $_ . ".timestamp", $new_feed->{lastModified});
            $dazeus->setProperty("plugins.wow." . $type . "feed." . $_ . ".level", $new_feed->{level});
        }
        else {
            print "same.\n";
        }
    }
}

# parse_fdfiff(network, channels, old_timestamp, old_level, new_feed)
# Parse difference between last seen and current feed, using the old timestamp
# and level. Will output all changes to the given channels (in the form of
# a hashmap with channels as keys).
sub parse_fdiff
{
    my ($netw, $chan, $old_timestamp, $old_level, $new_feed, $type) = @_;
    if($old_level != $new_feed->{level}) {
        for my $channel (keys %$chan) {
                $dazeus->message($netw, $channel, $new_feed->{name} . " (" . $new_feed->{realm} . ") has leveled up to level " . $new_feed->{level} . "! \\o/");
        }
    }
    my $item;
    my @feed;
    if($type eq "char") {
        @feed = reverse @{$new_feed->{feed}};
    }
    elsif($type eq "guild") {
        @feed = reverse @{$new_feed->{news}};
    }
    foreach $item (@feed)
    {
        if($item->{timestamp} > $old_timestamp) {
            if($item->{type} eq "ACHIEVEMENT") {
                for my $channel (keys %$chan) {
                    $dazeus->message($netw, $channel, $new_feed->{name} . " (" . $new_feed->{realm} . ") has gained [" . $item->{achievement}{title} . "]! \\o/");
                }
            }
            if($item->{type} eq "guildAchievement") {
                for my $channel (keys %$chan) {
                    print "Say to ". $netw . " ; " . $channel . "\n";
                    $dazeus->message($netw, $channel, $new_feed->{name} . " (" . $new_feed->{realm} . ") has gained [" . $item->{achievement}{title} . "]! \\o/");
                }
            }
            elsif($item->{type} eq "LOOT") {
                my $itemdat = $wow_api->GetItem($item->{itemId});
                for my $channel (keys %$chan) {
                    $dazeus->message($netw, $channel, $new_feed->{name} . " (" . $new_feed->{realm} . ") has looted " . $itemdat->{name} . "! \\o/");
                }
            }
            elsif($item->{type} eq "BOSSKILL") {
                for my $channel (keys %$chan) {
                    $dazeus->message($netw, $channel, $new_feed->{name} . " (" . $new_feed->{realm} . ") has cleared " . $item->{name} . "! \\o/");
                }
            }
        }
    }
}

# toggle_feed(network, channel, "on"/"off")
# Subscribe or unsubscribe a channel from feeds.
sub toggle_feeds
{
    my ($netw, $chan, $flag) = @_;
    print "Setting feed subscription for " . $chan . " to " . $flag . "\n";
    
    my $subs = $dazeus->getProperty("plugins.wow.subscribers");
    if(!$subs){
        $subs = {};
    }
    
    if($flag eq "on"){
        if(exists($subs->{$chan})){
            $dazeus->message($netw, $chan, "But this channel is already subscribed!");
            return;
        }
        else {
            $subs->{$chan} = 1;
            $dazeus->message($netw, $chan, "I will subscribe this channel.");
        }
    }
    elsif($flag eq "off"){
        if(exists($subs->{$chan})){
            delete $subs->{$chan};
            $dazeus->message($netw, $chan, "I will unsubscribe this channel.");
        }
        else {
            $dazeus->message($netw, $chan, "But this channel is not subscribed!");
            return;
        }
    }
    
    $dazeus->setProperty("plugins.wow.subscribers", $subs);
}

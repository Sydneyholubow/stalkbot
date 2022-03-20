#!/usr/bin/perl

# Reads a JSON file of websites and keyphrases and loads each
# webpage and sends an alert if none of the keyphrases are found.

use JSON;
use URI::Escape;

$JSONFILE = "/home/pi/stalk/stalk.json";
$HTMLFILE = "/home/pi/stalk/stalk.html";

my $timeout = 20;
my $sleep_duration = 180;
my $quit = 0;
my $api_key = '1644234032:AAGQwWsUDZqfSVwg88Y0fDw5F2wqxEy3dFQ';
my $chat_id = "1466486273";

unless (-e $JSONFILE) {
  print "$JSONFILE does not exist!\n";
  exit;
}

open(FILE, "$JSONFILE") or die $!;
@config = <FILE>;
close(FILE);

# Strip spaces and newlines outside quoted strings
my @json_text = split /\n/, join('',@config);

# Decode JSON to Perl data structure
my $json = JSON->new;
my $data = $json->decode(join('',@json_text));

# Main loop
while (true) {
  # Iterate through each website
  $index = 0;
  for ( @{$data->{data}} ) {
    my $id = $_->{id};
    my $url = $_->{url};
    my @keyphrases = @{$_->{keyphrases}};
    my $active = $_->{active};



    if ($id ne "" and $active ne "0") {
      print "Loading $id - $url...\n";

      # Define curl command with request headers to pretend that we're a Chrome browser on Windows 10
      my $curl = "curl -k -i -L" 
        . " -H \"ACCEPT: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9\""
        . " -H \"ACCEPT-ENCODING: gzip, deflate, br\""
        . " -H \"ACCEPT-LANGUAGE: en-US,en;q=0.9,ar;q=0.8\""
        . " -H \"DEVICE-MEMORY: 8\""
        . " -H \"DOWNLINK: 10\""
        . " -H \"DPR: 1\""
        . " -H \"ECT: 4g\""
        . " -H \"RTT: 50\""
        . " -H \"SEC-CH-UA: \\\"Chromium\\\";v=\\\"88\\\", \\\"Google Chrome\\\";v=\\\"88\\\", \\\";Not A Brand\\\";v=\\\"99\\\"\""
        . " -H \"SEC-CH-UA-FULL-VERSION: \\\"88.0.4324.104\\\"\""
        . " -H \"SEC-CH-UA-MOBILE: ?0\""
        . " -H \"SEC-CH-UA-PLATFORM: \\\"Windows\\\"\""
        . " -H \"SEC-CH-UA-PLATFORM-VERSION: \\\"10.0\\\"\""
        . " -H \"SEC-FETCH-DEST: document\""
        . " -H \"SEC-FETCH-MODE: navigate\""
        . " -H \"SEC-FETCH-SITE: cross-site\""
        . " -H \"SEC-FETCH-USER: ?1\""
        . " -H \"UPGRADE-INSECURE-REQUESTS: 1\""
        . " -H \"USER-AGENT: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/87.0.4280.141 Safari/537.36\""
        . " -H \"VIEWPORT-WIDTH: 1920: \""
        . " -f -m $timeout --compressed \'$url\'";

      # Load website content into a string using curl with specific parameters
      my $content = `$curl`;
      my $exit_value  = $? >> 8;

      # Make sure content was fetched and there were no curl errors
      if (($content ne "") && ($exit_value == 0)) {
        # Set variable to none found
        my $nonefound = 1;

        # Iterate through each keyphrase
        foreach $keyphrase (@keyphrases) {
          if ($nonefound) {
            print "Searching for keyphrase: $keyphrase\n";
            if (index($content, $keyphrase) != -1) {
              $nonefound = 0;
            }
          }
        }

        # Alert, log, and exit if no search terms were found on a website
        if ($nonefound eq 0) {
          $msg = uri_escape("$id\n$url");
          print `curl -s \"https://api.telegram.org/bot$api_key/sendMessage?chat_id=$chat_id&text=$msg\"`;

          # Write content to file for later analysis
          open(FILE, "> $HTMLFILE") or die $!;
          print FILE $content;
          close(FILE);

          # Remove website from hash of hashes
          delete($data->{data}[$index]);

          if ($quit) {
            exit;
          }
        }
      }
      print "\n";
    }
    $index++;
  }

  print "Sleeping for $sleep_duration seconds...\n";
  sleep($sleep_duration);
  print "\n";
}


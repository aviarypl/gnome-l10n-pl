#!/usr/bin/perl

#
# diffs two .po files and writes a report with changed, added and removed messages
# (c) Wadim Dziedzic, 2009
#

use Locale::PO;

# glues the plural strings together - it is enough for comparison
# @param 1 - a Locale::PO object to inspect
sub handlePlurals($) {
	my $po = $_[0];
	my $pluralstr = "";
	$plurals = $po->msgstr_n();
	foreach $k (keys %{$plurals}) {
		$pluralstr .= $plurals->{$k};
	}
	return $pluralstr;
}

# prepares messages for a report
# @param 1 - a Locale::PO object to print
# @param 2 - type of message (ORG, OLD, NEW)
sub printMessage {
	my $po = $_[0];
	my $type = $_[1];
	my $ret = "";

	if($type eq "ORG") {
		# prepare original string
		$ret = "msgid           :".$po->msgid()."\n";
		if( ! ($po->msgid_plural() eq "") ) {
			$ret .= "msgid_plural    :".$po->msgid_plural()."\n";
		}
	}
	else {
		# prepare string with OLD/NEW translation
		$fuzzystr = "  ";
		if( $po->fuzzy() ) {
			$fuzzystr = "F ";
		}
		if (! ($po->msgid_plural() eq "")) {
			$plurals = $po->msgstr_n();
			foreach $k (sort keys %{$plurals}) {
				$ret .= "msgstr[$k] $type $fuzzystr:".$plurals->{$k}."\n";
			}
		}
		else {
			$ret .= "msgstr $type    $fuzzystr:".$po->msgstr()."\n";	
		}
	}
	return $ret;
}

# MAIN PROGRAM

$OLDFILE = $ARGV[0];
$NEWFILE = $ARGV[1];
$error = false;

if ( !(-r $OLDFILE) || !(-r $NEWFILE) ) {
	print "Usage: msgdiff.pl <old_po_file> <new_po_file>\n";
	exit 1;
}

%result = ();
$oldhash = Locale::PO->load_file_ashash($OLDFILE);
$newhash = Locale::PO->load_file_ashash($NEWFILE);

# iterate over old hash and compare entries in newhash
while ( ($k,$v) = each %{$oldhash} ) {
	if (! $v->obsolete()) {
		if (exists(${$newhash}{$k})) {
			# key exists in both files - get it & compare it
			if ($v->msgid_plural() eq "") {
				$oldmsgstr=$v->msgstr();
				$newmsgstr=${$newhash}{$k}->msgstr();
			}
			else {
				$oldmsgstr = handlePlurals($v);
				$newmsgstr = handlePlurals(${$newhash}{$k});
			}

			if ( ! ($oldmsgstr eq $newmsgstr) ) {
				$result{$k} = "changed";
				$saved = $k;
				print STDERR "C";
			}
			else {
				print STDERR ".";
			}

		}
		else {
			# key exists only in old file - add it as removed
			$result{$k} = "removed";
			print STDERR "R";
		}
	}
}

print STDERR "\n";

# iterate over the new hash and search for new keys
foreach $k (keys %{$newhash}) {
	if (! $newhash->{$k}->obsolete()) {
		if (! exists(${$oldhash}{$k})) {
			# key exists only in new file - add it as new
			$result{$k} = "added";
			print STDERR "A";
		}
		else {
			print STDERR ".";
		}
	}
}
print "\n";

# print the results
my $changed;
my $added;
my $removed;

while ( ($k,$v) = each %result ) {
	if ($v eq "changed") {
		$changed .= printMessage(${$oldhash}{$k}, "ORG");
		$changed .= printMessage(${$oldhash}{$k}, "OLD");
		$changed .= printMessage(${$newhash}{$k}, "NEW");
		$changed .= "\n";
	}
	if ($v eq "added") {
		$added .= printMessage(${$newhash}{$k}, "ORG");
		$added .= printMessage(${$newhash}{$k}, "NEW");
		$changed .= "\n";
	}
	if ($v eq "removed") {
		$removed .= printMessage(${$oldhash}{$k}, "ORG");
		$removed .= printMessage(${$oldhash}{$k}, "OLD");
		$changed .= "\n";
	}
}

if ( ! ($changed eq "")) {
	print "\n =============== CHANGED MESSAGES =============== \n";
	print $changed;
}
if ( ! ($added eq "")) {
	print "\n ===============  ADDED MESSAGES  =============== \n";
	print $added;
}
if ( ! ($removed eq "")) {
	print "\n =============== REMOVED MESSAGES =============== \n";
	print $removed;
}


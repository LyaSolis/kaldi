#!/usr/bin/env perl
#
# Copyright 2014  David Snyder  Daniel Povey
# Apache 2.0.

use File::Basename;
if (@ARGV != 2) {
  print STDERR "Usage: $0 <path-to-LDC96S*> <path-to-output>\n";
  print STDERR "e.g. $0 /export/corpora/NIST/lid96e1 data\n";
  exit(1);
}

($db_base, $out_base_dir) = @ARGV;

$ldc_code = lc basename($db_base);

foreach $set ('3', '10', '30') {
  $tmp_dir = "$out_base_dir/tmp";
  if (system("mkdir -p $tmp_dir") != 0) {
    die "Error making directory $tmp_dir"; 
  }
  
  if (system("find $db_base/test/$set -name '*.sph' | grep '$set' > $tmp_dir/sph.list")
    != 0) {
    die "Error getting list of sph files";
  }
  
  $tmp_dir = "$out_base_dir/tmp";
  open(WAVLIST, "<", "$tmp_dir/sph.list") or die "cannot open wav list";

  %wav = ();
  while($sph = <WAVLIST>) {
    chomp($sph);
    @A = split("/", $sph);
    $basename = $A[$#A];
    $raw_basename = $basename;
    $raw_basename =~ s/\.sph$// || die "bad basename $basename";
    $wav{$raw_basename} = $sph;
  }

  close(WAVLIST) || die;

  $out_dir = $out_base_dir . "/" . $ldc_code . '_' . $set;
  if (system("mkdir -p $out_dir") != 0) {
    die "Error making directory $out_dir"; 
  }

  %utt2lang = ();
  open(SEG, "<$db_base/test/$set/seg_lang.ndx") || die "Failed to open $db_base/test/$set/seg_lang.ndx";
  while ($line = <SEG>) {
    chomp($line);
    ($utt, $lang) = split(" ", $line);
    $utt2lang{$utt} = $lang;
  }

  open(WAV, ">$out_dir" . '/wav.scp') 
    || die "Failed opening output file $out_dir/wav.scp";
  open(UTT2LANG, ">$out_dir" . '/utt2lang') 
    || die "Failed opening output file $out_dir/utt2lang";
  open(UTT2SPK, ">$out_dir" . '/utt2spk') 
    || die "Failed opening output file $out_dir/utt2spk";

  foreach $recording (sort keys(%wav)) {
    foreach $channel ( (1, 2) ) {
      $uttId = $ldc_code . "_" . $recording . "_" . $channel;
      print WAV "$uttId"," sph2pipe -f wav -p -c ${channel} $wav{$recording} |\n";
      print UTT2SPK "$uttId $uttId\n";
      print UTT2LANG "$uttId $utt2lang{$recording}\n";
    }
  }

  close(WAV) || die;
  close(UTT2SPK) || die;
  close(UTT2LANG) || die;
  system("rm -r $out_base_dir/tmp");

  system("utils/fix_data_dir.sh $out_dir");
  (system("utils/validate_data_dir.sh --no-text --no-feats $out_dir") == 0) 
    || die "Error validating data dir.";
}

cat > /tmp/probe4.pl <<'PLEOF'
use strict; use Socket;
my $AF=42; my $node=3; my $port=9; my $DG=2; my $TXN=0;
my %en=(0=>"OK",1=>"MALFORMED",17=>"MISSING_ARG",19=>"INVALID_ARG",22=>"NOMEM",26=>"NOTSUP",57=>"NOTSUP",73=>"INVID",42=>"E42",58=>"E58",5=>"E5",3=>"INTERNAL",8=>"E8",2=>"E2",9=>"E9",4=>"E4",6=>"E6_notfound?");
sub req {
  my ($msgid,$tlvhex)=@_; $TXN++; my $mytxn=$TXN & 0xffff;
  socket(my $s,$AF,$DG,0) or die;
  my $dest=pack("S x2 L L",$AF,$node,$port);
  my $tlvs=pack("H*",$tlvhex);
  my $msg=pack("C v v v",0,$mytxn,$msgid,length($tlvs)).$tlvs;
  send($s,$msg,0,$dest);
  my $end=time()+2;
  while(time()<$end){
    my $rin=""; vec($rin,fileno($s),1)=1; my $n=select(my $r=$rin,undef,undef,0.4); next if $n<=0;
    my $from=recv($s,my $b,8192,0); next unless defined $from;
    my @h=unpack("C v v v",$b);
    next unless ($h[1]==$mytxn && $h[2]==$msgid);
    close($s);
    my @by=unpack("C*",$b); my $err=0; my $i=7; my $extra="";
    while($i+3<=scalar(@by)){ my $t=$by[$i]; my $l=$by[$i+1]|($by[$i+2]<<8);
      my $v=($l>0)?join("",map{sprintf"%02x",$_}@by[$i+3..$i+2+$l]):"";
      if($t==2 && $l==4){ $err=$by[$i+5]|($by[$i+6]<<8);} else { $extra.=sprintf" T%02x(%d)=%s",$t,$l,$v; }
      $i+=3+$l; }
    return (($en{$err}//"e$err"),$extra);
  }
  close($s); return ("NORESP","");
}
sub tlv { my($t,$vh)=@_; my $n=length($vh)/2; return sprintf("%02x%02x%02x",$t,$n&0xff,($n>>8)&0xff).$vh; }
sub hx { unpack("H*",shift) }
sub pv { my $ph=hx(shift); my $n=length($ph)/2; return sprintf("%02x%02x",$n&0xff,($n>>8)&0xff).$ph; }
sub t { my($m,$tl,$lbl)=@_; select(undef,undef,undef,0.06); my($e,$x)=req($m,$tl); printf "  %-46s 0x%04x -> %-13s%s\n",$lbl,$m,$e,$x; }
my $NX="/policyman/persisted_items/zzclaudetest";
my $REAL="/policyman/persisted_items/limited_bands";
print "==== 0x0020 accumulate mandatory TLVs (path=NX, zeros) ====\n";
t(0x0020, tlv(1,pv($NX)).tlv(2,"0000"), "01+02");
t(0x0020, tlv(1,pv($NX)).tlv(2,"0000").tlv(3,"00000000"), "01+02+03");
t(0x0020, tlv(1,pv($NX)).tlv(2,"0000").tlv(3,"00000000").tlv(4,"00000000"), "01+02+03+04");
t(0x0020, tlv(1,pv($NX)).tlv(2,"0000").tlv(3,"00000000").tlv(4,"00000000").tlv(5,"00000000"), "01..05");
t(0x0020, tlv(1,pv($NX)).tlv(2,"0000").tlv(3,"00000000").tlv(4,"00000000").tlv(5,"00"), "01..04+05=u8");
print "==== 0x0020 on REAL file, all-zero params ====\n";
t(0x0020, tlv(1,pv($REAL)).tlv(2,"0000").tlv(3,"00000000").tlv(4,"00000000"), "01+02+03+04 REAL");
print "==== 0x0021 path-format variants (raw string TLV01) ====\n";
for my $p ("/policyman","policyman","/policyman/","/","/policyman/persisted_items","$REAL","limited_bands","/nv","nv"){
  t(0x0021, tlv(1,hx($p)),      "raw '$p'");
}
t(0x0021, tlv(1,hx("/policyman")."00"), "raw /policyman + NUL");
print "==== 0x001e re-run (info) ====\n";
t(0x001e, "", "no-arg");
PLEOF
echo "=== probe4 ==="
perl /tmp/probe4.pl
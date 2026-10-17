cat > /tmp/probe2.pl <<'PLEOF'
use strict; use Socket; 
my $AF=42; my $node=3; my $port=9; my $DG=2; my $TXN=0;
my %en=(0=>"OK",1=>"MALFORMED",17=>"MISSING_ARG",19=>"INVALID_ARG",22=>"NOMEM",26=>"NOTSUP",57=>"NOTSUP",73=>"INVID",42=>"E42",58=>"E58",5=>"E5",3=>"INTERNAL",8=>"E8");
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
    my @h=unpack("C v v v",$b); # flags,txn,msgid,len
    next unless ($h[1]==$mytxn && $h[2]==$msgid);   # verify echo => no race
    close($s);
    my @by=unpack("C*",$b); my $err=0; my $i=7; my $extra="";
    while($i+3<=scalar(@by)){ my $t=$by[$i]; my $l=$by[$i+1]|($by[$i+2]<<8);
      my $v=($l>0)?join("",map{sprintf"%02x",$_}@by[$i+3..$i+2+$l]):"";
      if($t==2 && $l==4){ $err=$by[$i+5]|($by[$i+6]<<8);} else { $extra.=sprintf" T%02x=%s",$t,$v; }
      $i+=3+$l; }
    return (($en{$err}//"e$err"),$extra);
  }
  close($s); return ("NORESP","");
}
sub tlv { my($t,$vh)=@_; my $n=length($vh)/2; return sprintf("%02x%02x%02x",$t,$n&0xff,($n>>8)&0xff).$vh; }
sub hx { unpack("H*",shift) }
sub t { my($m,$tl,$lbl)=@_; select(undef,undef,undef,0.06); my($e,$x)=req($m,$tl); printf "  %-34s 0x%04x -> %-12s%s\n",$lbl,$m,$e,$x; }
my $P=hx("/policyman"); my $PF=hx("/policyman/persisted_items/limited_bands");
print "==== race-free re-confirm the ambiguous 0x0020 cases ====\n";
t(0x0020, tlv(1,"0000"),          "TLV01=2B zero");
t(0x0020, tlv(1,"00"x10),         "TLV01=10B zero");
t(0x0020, tlv(1,$P),              "TLV01=/policyman(10B ascii)");
t(0x0020, tlv(1,"4142"),          "TLV01=2B 'AB'");
print "==== 0x0020: TLV01=u16(0) + second TLV = path+NUL, vary type ====\n";
for my $T (0x02,0x03,0x04,0x10,0x11,0x12,0x16){ t(0x0020, tlv(1,"0000").tlv($T,$P."00"), sprintf("01=u16 + T%02x=path",$T)); }
print "==== 0x0020: TLV01=u16(0) + second TLV = u32, vary type ====\n";
for my $T (0x02,0x10){ t(0x0020, tlv(1,"0000").tlv($T,"00000000"), sprintf("01=u16 + T%02x=u32",$T)); }
print "==== 0x0021 race-free ====\n";
t(0x0021, tlv(1,$P),              "TLV01=/policyman");
t(0x0021, tlv(1,$PF),             "TLV01=fullpath");
t(0x0021, tlv(1,$PF."00"),        "TLV01=fullpath+NUL");
t(0x0021, tlv(1,"0000").tlv(2,$P."00"), "01=u16 + T02=path");
print "==== 0x001f race-free (u16 values) ====\n";
for my $v ("0000","0100","ffff","0500"){ t(0x001f, tlv(1,$v), "TLV01=u16 $v"); }
PLEOF
echo "=== race-free probe ==="
perl /tmp/probe2.pl
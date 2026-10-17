cat > /tmp/probe3.pl <<'PLEOF'
use strict; use Socket;
my $AF=42; my $node=3; my $port=9; my $DG=2; my $TXN=0;
my %en=(0=>"OK",1=>"MALFORMED",17=>"MISSING_ARG",19=>"INVALID_ARG",22=>"NOMEM",26=>"NOTSUP",57=>"NOTSUP",73=>"INVID",42=>"E42_badhdl?",58=>"E58",5=>"E5_notfound?",3=>"INTERNAL",8=>"E8",2=>"E2");
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
      my $v=($l>0 && $i+2+$l<scalar(@by)+1)?join("",map{sprintf"%02x",$_}@by[$i+3..$i+2+$l]):"";
      if($t==2 && $l==4){ $err=$by[$i+5]|($by[$i+6]<<8);} else { $extra.=sprintf" T%02x(%d)=%s",$t,$l,$v; }
      $i+=3+$l; }
    return (($en{$err}//"e$err"),$extra);
  }
  close($s); return ("NORESP","");
}
sub tlv { my($t,$vh)=@_; my $n=length($vh)/2; return sprintf("%02x%02x%02x",$t,$n&0xff,($n>>8)&0xff).$vh; }
sub hx { unpack("H*",shift) }
sub pv { my $ph=hx(shift); my $n=length($ph)/2; return sprintf("%02x%02x",$n&0xff,($n>>8)&0xff).$ph; } # {u16 len; path}
sub t { my($m,$tl,$lbl)=@_; select(undef,undef,undef,0.06); my($e,$x)=req($m,$tl); printf "  %-40s 0x%04x -> %-14s%s\n",$lbl,$m,$e,$x; }
my $NX="/policyman/persisted_items/zzclaudetest";  # nonexistent (safe)
my $DIR="/policyman";
my $NVDIR="/nv";
print "==== model check: TLV01={u16 len; path}, empty path ====\n";
t(0x0020, tlv(1,pv("")),   "0x20 path=empty");
print "==== 0x001f with length-prefixed path (nonexistent/dir) ====\n";
t(0x001f, tlv(1,pv($NX)),  "0x1f path=NX");
t(0x001f, tlv(1,pv($DIR)), "0x1f path=/policyman");
t(0x001f, tlv(1,pv($NVDIR)),"0x1f path=/nv");
print "==== 0x0020 with length-prefixed path (nonexistent) ====\n";
t(0x0020, tlv(1,pv($NX)),  "0x20 path=NX");
t(0x0020, tlv(1,pv($DIR)), "0x20 path=/policyman");
print "==== 0x0021 with length-prefixed path (nonexistent/dir) ====\n";
t(0x0021, tlv(1,pv($NX)),  "0x21 path=NX");
t(0x0021, tlv(1,pv($DIR)), "0x21 path=/policyman");
print "==== 0x0020 second-TLV search (valid path + T2 various) ====\n";
for my $T (0x02,0x03,0x04){
  t(0x0020, tlv(1,pv($NX)).tlv($T,"00"),         sprintf("0x20 NX + T%02x=u8",$T));
  t(0x0020, tlv(1,pv($NX)).tlv($T,"0000"),       sprintf("0x20 NX + T%02x=u16",$T));
  t(0x0020, tlv(1,pv($NX)).tlv($T,"00000000"),   sprintf("0x20 NX + T%02x=u32",$T));
}
PLEOF
echo "=== corrected path-struct probe ==="
perl /tmp/probe3.pl
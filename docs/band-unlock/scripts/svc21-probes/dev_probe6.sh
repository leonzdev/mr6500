cat > /tmp/probe6.pl <<'PLEOF'
use strict; use Socket;
my $AF=42; my $node=3; my $port=9; my $DG=2; my $TXN=0;
my %en=(0=>"OK",1=>"MALFORMED",9=>"INVHANDLE",17=>"MISSING_ARG",19=>"ARG_TOO_LONG",
        22=>"NOMEM",26=>"NOTSUP",57=>"e57NOTSUP",73=>"INVID",42=>"e42",58=>"e58",5=>"e5",3=>"INTERNAL",6=>"e6",14=>"e14");
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
    my @h=unpack("C v v v",$b); next unless ($h[1]==$mytxn && $h[2]==$msgid);
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
my $NX="/policyman/persisted_items/zzclaudetest"; my $nxh=hx($NX); my $nxlen=length($NX);
# pattern A: {u16 len; char path[N]}  (len-prefixed, fixed buffer N)
sub bufA { my $N=shift; my $pad="00" x ($N-$nxlen); return sprintf("%02x%02x",$nxlen&0xff,($nxlen>>8)&0xff).$nxh.$pad; }
# pattern B: {char path[N]} null-padded fixed array (no len prefix)
sub bufB { my $N=shift; my $pad="00" x ($N-$nxlen); return $nxh.$pad; }
print "==== 0x0021 : pattern A {u16 len; path[N]} scan N ====\n";
for my $N (32,48,64,80,96,100,128,180,200,255,256,260,300,384,512,960,1024){
  select(undef,undef,undef,0.04); my ($e,$x)=req(0x0021, tlv(1,bufA($N)));
  printf "  A N=%-4d (tlvlen=%d) -> %s%s\n",$N,$N+2,$e,$x;
}
print "==== 0x0021 : pattern B {path[N]} null-padded scan N ====\n";
for my $N (64,128,255,256,384,512,960,1024){
  select(undef,undef,undef,0.04); my ($e,$x)=req(0x0021, tlv(1,bufB($N)));
  printf "  B N=%-4d -> %s%s\n",$N,$e,$x;
}
print "==== 0x0020 : also try pattern A fixed buffer for TLV01 ====\n";
for my $N (255,256,384,512){
  select(undef,undef,undef,0.04); my ($e,$x)=req(0x0020, tlv(1,bufA($N)).tlv(2,"0000").tlv(3,"00000000"));
  printf "  0x20 A N=%-4d +02+03 -> %s%s\n",$N,$e,$x;
}
PLEOF
echo "=== probe6 fixed-buffer scan ==="
perl /tmp/probe6.pl
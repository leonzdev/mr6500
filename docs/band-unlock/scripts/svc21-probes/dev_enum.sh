cat > /tmp/enum.pl <<'PLEOF'
use strict; use Socket;
my $AF=42; my $node=3; my $port=9; my $DG=2;
my %ename=(0=>"OK",1=>"NONE",2=>"MALFORMED_MSG",17=>"MISSING_ARG",19=>"INVALID_ARG",
  22=>"NO_MEMORY",26=>"NOT_SUPPORTED",73=>"INVALID_ID",90=>"NOT_PROVISIONED",
  0x35=>"INVALID_HANDLE",0x36=>"INVALID_PROFILE",0x5e=>"NOT_SUPPORTED2");
for (my $msgid=0x0000; $msgid<=0x0040; $msgid++){
  socket(my $s,$AF,$DG,0) or die;
  my $dest=pack("S x2 L L",$AF,$node,$port);
  my $msg=pack("C v v v",0,1,$msgid,0);
  send($s,$msg,0,$dest);
  my $got="";
  my $end=time()+1;
  while(time()<$end){ my $rin=""; vec($rin,fileno($s),1)=1; my $n=select(my $r=$rin,undef,undef,0.4); next if $n<=0; recv($s,my $b,8192,0); $got=$b; last; }
  close($s);
  if($got eq ""){ next; }   # no response = likely not-registered msg
  my @b=unpack("C*",$got);
  my ($res,$err)=("?","?"); my $i=7;
  while($i+3 <= scalar(@b)){ my $t=$b[$i]; my $l=$b[$i+1]|($b[$i+2]<<8); if($t==2 && $l==4){ $res=$b[$i+3]|($b[$i+4]<<8); $err=$b[$i+5]|($b[$i+6]<<8); last;} $i+=3+$l; }
  my $en=$ename{$err}//"err$err";
  printf "msg 0x%04x -> result=%s error=%s(%d)  len=%d  raw=%s\n",$msgid,$res,$en,$err,scalar(@b),unpack("H*",$got);
}
PLEOF
echo "=== svc21 (node3:port9) message enumeration 0x0000-0x0040 (no TLV) ==="
perl /tmp/enum.pl
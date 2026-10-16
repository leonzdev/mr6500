cat > /tmp/lenscan.pl <<'PLEOF'
use strict; use Socket;
my $AF=42; my $node=3; my $port=9; my $DG=2;
my %en=(0=>"OK",1=>"MALFORMED",17=>"MISSING_ARG",19=>"INVALID_ARG",22=>"NOMEM",26=>"NOTSUP",57=>"NOTSUP",73=>"INVID",42=>"E42",58=>"E58",5=>"E5",3=>"INTERNAL");
sub req {
  my ($msgid,$tlvhex)=@_;
  socket(my $s,$AF,$DG,0) or die;
  my $dest=pack("S x2 L L",$AF,$node,$port);
  my $tlvs=pack("H*",$tlvhex);
  my $msg=pack("C v v v",0,1,$msgid,length($tlvs)).$tlvs;
  send($s,$msg,0,$dest);
  my $got=""; my $end=time()+2;
  while(time()<$end){ my $rin=""; vec($rin,fileno($s),1)=1; my $n=select(my $r=$rin,undef,undef,0.4); next if $n<=0; recv($s,my $b,8192,0); $got=$b; last; }
  close($s);
  return ("NORESP","") if $got eq "";
  my @b=unpack("C*",$got); my $err=0; my $i=7; my $extra="";
  while($i+3<=scalar(@b)){ my $t=$b[$i]; my $l=$b[$i+1]|($b[$i+2]<<8);
    my $v=($l>0)?join("",map{sprintf"%02x",$_}@b[$i+3..$i+2+$l]):"";
    if($t==2 && $l==4){ $err=$b[$i+5]|($b[$i+6]<<8);} else { $extra.=sprintf" T%02x=%s",$t,$v; }
    $i+=3+$l; }
  return (($en{$err}//"e$err"),$extra);
}
sub tlv { my($t,$vh)=@_; my $n=length($vh)/2; return sprintf("%02x%02x%02x",$t,$n&0xff,($n>>8)&0xff).$vh; }
for my $m (0x001f,0x0020,0x0021){
  printf "==== msg 0x%04x : TLV01 = N zero bytes ====\n",$m;
  my $line="";
  for my $N (0..20){
    my ($e,$x)=req($m, tlv(1,"00" x $N));
    $line.=sprintf("N=%-2d:%-11s ",$N,$e);
    if(($N+1)%4==0){ print "  $line\n"; $line=""; }
  }
  print "  $line\n" if $line;
}
PLEOF
echo "=== TLV01 length scan ==="
perl /tmp/lenscan.pl
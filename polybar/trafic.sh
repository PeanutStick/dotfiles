INTERFACE=enp34s0
ms=$(ping -c 1 1.1.1.1 |awk 'FNR==2{print $7}' | cut -c6- )

rxtx=$(awk '{
  if (rx) {
    printf ("  %.0f    %.0f\n", ($2-rx)/1024, ($10-tx)/1024)
  } else {
    rx=$2; tx=$10;
  }
}' \
    <(grep $INTERFACE /proc/net/dev) \
    <(sleep 1; grep $INTERFACE /proc/net/dev))
rx=$(echo $rxtx | cut -d' ' -f1)
tx=$(echo $rxtx | cut -d' ' -f2)
if [[ $rx -gt 1000 ]]
then
	rx=$((($rx+512)/1024))"MB/s"
else
	rx=$d"kB/s"
fi
if [[ $tx -gt 1000 ]]
then
        tx=$((($tx+512)/1024))"MB/s"
else
	tx=$tx"kB/s"
fi
	echo "[ ▼ "$rx" ▲ "$tx" "$ms" ]"

#!/bin/sh
# Enable USB 3 on the lemonadep DTB (runs in chroot_native, $1 = DTB): QMP USB3/DP combo PHY on with the
# supplies used by sm8350-hdk/mtp (vdda-phy L1B 0.88 V, vdda-pll L6B 1.2 V), dwc3 gets usb3-phy and no
# high-speed cap, pipe clock from the PHY, and the pmic-glink connector SS port linked to the PHY
# (orientation switch for pmic_glink_altmode).
# $2 = stage: a = QMP PHY on (dwc3 untouched), b = + dwc3 usb3-phy (UTMI pipe clock kept),
# c / full = + pipe clock from the PHY, super-speed and the orientation graph (hangs at boot, 2026-11-12)
# c1 = b + pipe clock from the PHY + super-speed (no graph; hangs too); c2 = b + orientation graph only
# c3 = c1 + the usb_1 interconnects our DT deletes (sm8350.dtsi values)
# c8 = c7 + orientation graph; c7 = c1 with super-speed-plus (avoids the LLUCTL oops); c4 = c1 + QMP usb3phy_portselect pinctrl (gpio81 usb_phy); c6 = c1 + dr_mode=host
set -e
D=$1; ST=${2:-full}
QP=/soc@0/phy@88e8000; G=/soc@0/usb@a6f8800; U=$G/usb@a600000; C=/pmic-glink/connector@0/ports
NEXT=$(dtc -I dtb -O dts $D 2>/dev/null | sed -n 's/.*phandle = <\(0x[0-9a-f]*\)>.*/\1/p' | while read h; do printf "%d\n" $h; done | sort -n | tail -1)
newph() { NEXT=$((NEXT + 1)); }
# phandle of a regulator node, created if the node has none (pm8350_l1 is unreferenced in our DT)
regph() {
  for n in 0 1 2 3 4 5; do
    for l in ldo1 ldo2 ldo3 ldo4 ldo5 ldo6 ldo7 ldo8 ldo9 ldo10; do
      R=/soc@0/rsc@18200000/regulators-$n/$l
      [ "$(fdtget $D $R regulator-name 2>/dev/null || true)" = "$1" ] || continue
      ph=$(fdtget $D $R phandle 2>/dev/null || true)
      if [ -z "$ph" ]; then newph; ph=$NEXT; fdtput $D $R phandle $ph; fi
      echo $ph; return 0
    done
  done
  return 1
}
L1=$(regph pm8350_l1) || { echo "usb3-dt: pm8350_l1 not found"; exit 1; }
[ "$L1" -gt "$NEXT" ] 2>/dev/null && NEXT=$L1
L6=$(regph pm8350_l6) || { echo "usb3-dt: pm8350_l6 not found"; exit 1; }
HS=$(fdtget $D /soc@0/phy@88e3000 phandle); QPH=$(fdtget $D $QP phandle)
fdtput -t s $D $QP status okay
fdtput $D $QP vdda-phy-supply $L1
fdtput $D $QP vdda-pll-supply $L6
if [ $ST = a ]; then echo "USB3DT[$ST]: qmp=$(fdtget $D $QP status) supplies=phy:$L1/pll:$L6"; exit 0; fi
fdtput $D $U phys $HS $QPH 0
fdtput -t s $D $U phy-names usb2-phy usb3-phy
if [ $ST = b ]; then echo "USB3DT[$ST]: qmp=okay supplies=phy:$L1/pll:$L6 phys=$(fdtget $D $U phys) speed=$(fdtget $D $U maximum-speed)"; exit 0; fi
if [ $ST != c2 ]; then
  fdtput -d $D $G qcom,select-utmi-as-pipe-clk
  fdtput -t s $D $U maximum-speed super-speed
fi
# c7 = c1 with maximum-speed super-speed-plus (vendor value). With "super-speed" dwc3 (DWC_usb31) forces
# Gen1 by reading LLUCTL at 0xd024, beyond the 0xcd00 reg window -> Oops in dwc3_core_init (the "hang")
if [ $ST = c7 ]; then
  fdtput -t s $D $U maximum-speed super-speed-plus
  echo "USB3DT[$ST]: phys=$(fdtget $D $U phys) speed=$(fdtget $D $U maximum-speed) pipe-utmi=removed graph=none"; exit 0
fi
if [ $ST = c3 ]; then
  A1=$(fdtget $D /soc@0/interconnect@16e0000 phandle); MV=$(fdtget $D /soc@0/interconnect@1580000 phandle 2>/dev/null || fdtget $D /interconnect-0 phandle)
  GN=$(fdtget $D /soc@0/interconnect@9100000 phandle); CN=$(fdtget $D /soc@0/interconnect@1500000 phandle)
  fdtput $D $G interconnects $A1 5 0 $MV 1 0 $GN 2 0 $CN 44 0
  fdtput -t s $D $G interconnect-names usb-ddr apps-usb
  echo "USB3DT[$ST]: speed=$(fdtget $D $U maximum-speed) pipe-utmi=removed icc=$(fdtget $D $G interconnects)"; exit 0
fi
# c4 = c1 + vendor usb3phy_portselect pinctrl on the QMP PHY (gpio81 function usb_phy, bias-disable, 2 mA)
if [ $ST = c4 ]; then
  T=/soc@0/pinctrl@f100000/usb3phy-portselect-state; newph
  fdtput -c $D $T; fdtput -t s $D $T pins gpio81; fdtput -t s $D $T function usb_phy
  fdtput -t s $D $T bias-disable ""; fdtput $D $T drive-strength 2; fdtput $D $T phandle $NEXT
  fdtput -t s $D $QP pinctrl-names default; fdtput $D $QP pinctrl-0 $NEXT
  echo "USB3DT[$ST]: speed=$(fdtget $D $U maximum-speed) pipe-utmi=removed pinctrl=$(fdtget $D $T function)/$NEXT"; exit 0
fi
# c6 = c1 + dwc3 fixed in host mode (no role switch, no gadget)
if [ $ST = c6 ]; then
  fdtput -t s $D $U dr_mode host; fdtput -d $D $U usb-role-switch; fdtput -d $D $U role-switch-default-mode 2>/dev/null || true
  echo "USB3DT[$ST]: speed=$(fdtget $D $U maximum-speed) pipe-utmi=removed dr_mode=$(fdtget $D $U dr_mode)"; exit 0
fi
if [ $ST = c1 ]; then echo "USB3DT[$ST]: phys=$(fdtget $D $U phys) speed=$(fdtget $D $U maximum-speed) pipe-utmi=removed graph=none"; exit 0; fi
# c8 = c7 (super-speed-plus) + orientation graph
[ $ST = c8 ] && fdtput -t s $D $U maximum-speed super-speed-plus
# graph: connector port@1 (SS) <-> QMP port@0 (out)
NEXT=$(dtc -I dtb -O dts $D 2>/dev/null | sed -n 's/.*phandle = <\(0x[0-9a-f]*\)>.*/\1/p' | while read h; do printf "%d\n" $h; done | sort -n | tail -1)
P1=$((NEXT + 1)); P2=$((NEXT + 2))
fdtput -c -p $D $C/port@1/endpoint
fdtput $D $C/port@1 reg 1
fdtput $D $QP/ports/port@0/endpoint phandle $P1
fdtput $D $C/port@1/endpoint phandle $P2
fdtput $D $QP/ports/port@0/endpoint remote-endpoint $P2
fdtput $D $C/port@1/endpoint remote-endpoint $P1
echo "USB3DT[$ST]: qmp=$(fdtget $D $QP status) supplies=phy:$L1/pll:$L6 phys=$(fdtget $D $U phys) names=$(fdtget $D $U phy-names) speed=$(fdtget $D $U maximum-speed) graph=$P1<->$P2 pipe-utmi=$(fdtget $D $G qcom,select-utmi-as-pipe-clk 2>/dev/null && echo still || echo removed)"

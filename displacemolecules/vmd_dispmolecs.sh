#!/bin/bh
############################################################################
#
# bash script vmd_displace_molecules.sh
#
# Description:
#
# Read two vmd compatible molecules, find geometrical center and displace
# into new periodic box with dimention x,y,z, and align in z-direction. 
# Displace according to thickness of lower molecule and the distance 
# between molecule1 and molecule2.
# Write output file with degree of rotation and estimated COM separation.
#
#      _______________
#      |   ______    |
#      |   |    |    |-> COM upper molecule
#      |   ------    |--
#      |             |  dist
#      |   ______    |__
#      |   |    |    |-> COM lower molecule
#      |   ------    |
#      |             |
#      ---------------
#
#                                  Author: Gøran Brekke Svaland 2016-06-22
###########################################################################

args=("$@")          # input arguments

# ---------------- Set values from input args --------------------------- #

molecule1=${args[0]} # upper molecule
molecule2=${args[1]} # lower molecule

x=${args[2]}         # pbc x
y=${args[3]}         # pbc y
z=${args[4]}         # pbc z

zm1=${args[5]}       # z displacement of lower molecule
dist=${args[6]}      # surface distance between molecules
deg=${args[7]}       # angle of horizontal (z) rotation for upper molecule
z0=${args[8]}        # initial separation of lower molecule
name=${args[9]}      # prefix of output filenames

#-- print input info
echo "molecule1: ${molecule1}"
echo "molecule2: ${molecule2}"
echo "x   =$x"
echo "y   =$y"
echo "z   =$z" 
echo "zm1 =$zm1"
echo "dist=${dist}"
echo "deg =${deg}"
echo "z0  =${z0}"

#-- midpoints of pbc system
xm=$(echo "scale=5; $x/2" | bc)  # x centering of slabs
ym=$(echo "scale=5; $y/2" | bc)  # y centering of slabs

#-- displacement of upper molecule
zm2=$(echo "scale=5; ${z0}+${dist}" | bc) 
# !NB: thickness of lower molecules is computed and taken into accout.

#-- output name of new pdb configuration
output="${name}_rot${deg}_sep${dist}" # acc. to rotation and separation

# ------------- create readable file for vmd  ------------- #

#-- temporary file
outfile="tmp.vmd"  # temporary input file for vmd

# --------------------------------------------------------- #
#-- proc for computing the geometrical center of a selection
#   commented out because I found that this method were
#   already implemented in VMD; measure center $selection
#echo -e 'proc geom_center {selection} {
#        set gc [veczero]
#        foreach coord [$selection get {x y z}] {
#           set gc [vecadd $gc $coord]
#        }
#        return [vecscale [expr 1.0 /[$selection num]] $gc]
#}' >> ${outfile}
# You may still use this metod with the call:
# set Rg [geom_center atomselect0]
# lassign $C a b c # assign elements in C to variables a,b,c
# --------------------------------------------------------- #

#-- load molecule, rotate an angle deg around z axis, and move
#-- to center of pbc box:
echo "mol new ${molecule1}" >> ${outfile}
echo "set sel [atomselect 0 all]" >> ${outfile}
echo "set C [measure center atomselect0]" >> ${outfile}
echo 'lassign $C a b c' >> ${outfile}
echo 'atomselect0 moveby [vecinvert $C]' >> ${outfile}
echo "atomselect0 moveby {0 0 ${zm2}}" >> ${outfile}
echo "atomselect0 move [transaxis z ${deg}]" >> ${outfile}

#-- load initial molecule to origin, and move into pbc box:
echo "mol new ${molecule2}" >> ${outfile}
echo "pbc set {${x} ${y} ${z}}" >> ${outfile}
echo "set sel [atomselect 1 all]" >> ${outfile}
echo "set D [measure center atomselect2]" >> ${outfile}
echo 'lassign $D d e f' >> ${outfile}
echo 'atomselect2 moveby [vecinvert $D]' >> ${outfile}
echo "atomselect2 moveby {0 0 ${zm1}}" >> ${outfile}

#-- move upper molecule according to thickness of the two
#   molecules. This assures that the the distance of
#   separation of the two molecules is according to the
#   geometrical thickness of the molecules.
echo 'set c1 "0 0 $c"' >> ${outfile}
echo 'set f1 "0 0 $f"' >> ${outfile}
echo 'atomselect0 moveby $c1' >> ${outfile}
echo 'atomselect0 moveby $f1' >> ${outfile}

#-- compute final geometrical positions of COM
echo "measure center atomselect0" >> ${outfile}
echo "measure center atomselect2" >> ${outfile}

#-- create new atomselection containing the two molecules,
#-- and move to center of simulation box:
echo "set kk {}" >> ${outfile}
echo "lappend kk atomselect0 atomselect2" >> ${outfile}
echo 'set mol [::TopoTools::selections2mol $kk]' >> ${outfile}
echo "set sel [atomselect 2 all]" >> ${outfile}
echo "atomselect10 moveby {${xm} ${ym} 0}" >> ${outfile}
echo "mol delete 0" >> ${outfile}
echo "mol delete 1" >> ${outfile}

#-- write output file:
echo "animate write pdb ${output}.pdb 2" >> ${outfile}
echo exit >> ${outfile}

vmd -e ${outfile} # run vmd with commands in ${outfile}
#rm ${outfile}     # delete temporary file: ${outfile}


#-- EOF

#!/bin/bash
strace="set; strace -e trace=open"
MONITOR="strace"
function copystage {
 # Copy directory $1 to $2, patch $2, and cd into the new directory of $2.
 # $1 = original directory with source code
 # $2 = new directory; start with cp -pr $1 $2

 echo
 echo "#### Copying $1 into $2"
 cp -pr $1 $2
 cd $2
 echo "### Now patching for 8-bit casting problem, 0.0 difference"
# Modify i386-asm.c to insert an extra temporary
# variable, so that we never hit the problem.

# Modify static void parse_operand(TCCState *s1, Operand *op)
perl -p -i -e 's/int reg, indir;/int reg, indir; int8_t tmp8;/;' i386-asm.c

perl -p -i -e 's/if \(op->e\.v == \(int8_t\)op->e\.v\)/if (tmp8 = op->e.v, op->e.v == tmp8)/;' i386-asm.c

# static inline void asm_modrm(int reg, Operand *op)
# Versions .27:
perl -p -i -e 's/int mod, reg1, reg2, sib_reg1;/int mod, reg1, reg2, sib_reg1; int8_t tmp8;/;' i386-asm.c
perl -p -i -e 's/} else if \(op->e\.v == \(int8_t\)op->e\.v && !op->e.sym\) \{/\} else if (tmp8 = op->e.v, op->e.v == tmp8 && !op->e.sym) \{/;' i386-asm.c

# static void asm_opcode(TCCState *s1, int opcode)
perl -p -i -e 's/int i, modrm_index, modreg_index, reg, v, op1, seg_prefix, pc;/int i, modrm_index, modreg_index, reg, v, op1, seg_prefix, pc; int8_t tmp8;/;' i386-asm.c

perl -p -i -e 's/if \(jmp_disp == \(int8_t\)jmp_disp\) \{/if (tmp8=jmp_disp, jmp_disp == tmp8) \{/;' i386-asm.c


# edits in tcc for 0.0
perl -p -i -e 's/ 0\.0\)/ (f1-f1) )/;' tcc.c
}

echo
echo "#### Retrust beginning"
echo

# Remove old stuff.
rm -fr tcc-0.9.2?-*
rm -fr tcc-0.9.27

# Let's show platform information

cat /proc/version
rpm -qi gcc
gcc --version
set

echo
echo "### Hashes of source files:"
echo

sha1sum *.tar.bz2
md5sum *.tar.bz2
ls -l *.tar.bz2

# Create the unchanged subdirectories.
tar xvf tcc-0.9.27.tar.bz2

# Do traditional chaining.
# Note that output (param 2) become the next param 3.

echo
echo "### Creating chain of tiny C compilers. First, bootstrap tcc."
echo

NEWDIR=tcc-0.9.27-chain-bootstrap
copystage tcc-0.9.27 $NEWDIR
perl -p -i -e 's/__attribute__\(\(regparm\(.\)\)\)//g;' *.[ch]

./configure --cc="$MONITOR gcc"
make libtcc1.a
make tcc
cd ..

PREVIOUSLIB=$NEWDIR
PREVIOUSCOMPILER=$NEWDIR
NEWDIR=tcc-0.9.27-chain-update
copystage tcc-0.9.27 $NEWDIR
./configure --cc="$MONITOR ../$PREVIOUSCOMPILER/tcc -B../$PREVIOUSLIB -I../$PREVIOUSLIB "
make libtcc1.a
make tcc
cd ..

PREVIOUSLIB=$NEWDIR
PREVIOUSCOMPILER=$NEWDIR
NEWDIR=tcc-0.9.27-chain-stage2
copystage tcc-0.9.27 $NEWDIR
./configure --cc="$MONITOR ../$PREVIOUSCOMPILER/tcc -B../$PREVIOUSLIB -I../$PREVIOUSLIB "
make libtcc1.a
./configure --cc="$MONITOR ../$PREVIOUSCOMPILER/tcc -B. -I. "
make tcc
cd ..

# Okay. Now tcc-0.9.27-byself was compiled through a chain.
echo
echo "#### Okay! Now let's do diverse double-compiling!"
echo

NEWDIR=tcc-0.9.27-bootstrap
copystage tcc-0.9.27 $NEWDIR
./configure --cc="$MONITOR gcc"
make libtcc1.a
make tcc
cd ..

PREVIOUSLIB=$NEWDIR
PREVIOUSCOMPILER=$NEWDIR
NEWDIR=tcc-0.9.27-stage2
copystage tcc-0.9.27 $NEWDIR
./configure --cc="$MONITOR ../$PREVIOUSCOMPILER/tcc -B../$PREVIOUSLIB -I../$PREVIOUSLIB "
make libtcc1.a
./configure --cc="$MONITOR ../$PREVIOUSCOMPILER/tcc -B. -I. "
make tcc
cd ..

PREVIOUSLIB=$NEWDIR
PREVIOUSCOMPILER=$NEWDIR
NEWDIR=tcc-0.9.27-stage3
copystage tcc-0.9.27 $NEWDIR
./configure --cc="$MONITOR ../$PREVIOUSCOMPILER/tcc -B../$PREVIOUSLIB -I../$PREVIOUSLIB "
make libtcc1.a
make tcc
cd ..

PREVIOUSLIB=$NEWDIR
PREVIOUSCOMPILER=$NEWDIR
NEWDIR=tcc-0.9.27-stage4
copystage tcc-0.9.27 $NEWDIR
./configure --cc="$MONITOR ../$PREVIOUSCOMPILER/tcc -B../$PREVIOUSLIB -I../$PREVIOUSLIB "
make libtcc1.a
make tcc
cd ..


echo
echo "### Here are the hash results for compiler (tcc) and runtime (libtcc1.o)"
echo

sha1sum */tcc | sort
echo
echo
sha1sum */lib/libtcc1.o | sort

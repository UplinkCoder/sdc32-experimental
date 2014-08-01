#!/bin/sh
dmd convtest.d jsonx.d 

dmd jsonRunner.d -I../src -I../libd-llvm/src -I../libd-llvm/libd/src -I../libd-llvm/import ../src/sdc/sdc.d ../src/sdc/conf.d ../src/util/json.d -L-L../lib -L-lpthread -L-ld-llvm -L-ld \
-L-lLLVMTableGen -L-lLLVMArchive -L-lLLVMInstrumentation -L-lLLVMLinker -L-lLLVMIRReader -L-lLLVMBitReader -L-lLLVMAsmParser \
-L-lLLVMipo -L-lLLVMVectorize \
-L-lLLVMDebugInfo -L-lLLVMOption -L-lLLVMX86Disassembler -L-lLLVMX86AsmParser -L-lLLVMX86CodeGen -L-lLLVMSelectionDAG -L-lLLVMAsmPrinter -L-lLLVMX86Desc -L-lLLVMX86Info -L-lLLVMX86AsmPrinter -L-lLLVMX86Utils -L-lLLVMMCDisassembler -L-lLLVMMCParser -L-lLLVMInterpreter -L-lLLVMBitWriter -L-lLLVMMCJIT -L-lLLVMJIT -L-lLLVMCodeGen -L-lLLVMObjCARCOpts -L-lLLVMScalarOpts -L-lLLVMInstCombine -L-lLLVMTransformUtils -L-lLLVMipa -L-lLLVMAnalysis -L-lLLVMRuntimeDyld -L-lLLVMExecutionEngine -L-lLLVMTarget -L-lLLVMMC -L-lLLVMObject -L-lLLVMCore -L-lLLVMSupport \
-L-lz -L-lpthread -L-lstdc++ -L-ldl

cp ../bin/sdc.conf ./

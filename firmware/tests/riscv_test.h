#ifndef _ENV_PICORV32_TEST_H
#define _ENV_PICORV32_TEST_H

#ifndef TEST_FUNC_NAME
#  define TEST_FUNC_NAME mytest
#  define TEST_FUNC_TXT "mytest"
#  define TEST_FUNC_RET mytest_ret
#endif

#define RVTEST_RV32U
#define TESTNUM x28

#define RVTEST_CODE_BEGIN		    \
	.text;				            \
	.global TEST_FUNC_NAME;		    \
	.global TEST_FUNC_RET;		    \
TEST_FUNC_NAME:				        \
	lui	    a0,%hi(.test_name);	    \
	addi	a0,a0,%lo(.test_name);	\
    jal     ra,puts;                \
    jal	    zero,.prname_done;	    \
.test_name:				            \
	.ascii TEST_FUNC_TXT;		    \
	.byte 0x00;			            \
	.balign 4, 0;		            \
.prname_done:				        \
	addi	a0,zero,'.';		    \
    jal     ra,outbyte;             \
    jal     ra,outbyte;
	
#define RVTEST_PASS			\
    addi    a0,zero,'O';    \
    jal     ra,outbyte;     \
	addi	a0,zero,'K';	\
    jal     ra,outbyte;     \
	addi	a0,zero,'\n';	\
    jal     ra,outbyte;     \
	jal	    zero,TEST_FUNC_RET;

#define RVTEST_FAIL			\
	addi	a0,zero,'E';    \
    jal     ra,outbyte;     \
	addi	a0,zero,'R';	\
    jal     ra,outbyte;     \
    jal     ra,outbyte;     \
	addi	a0,zero,'O';	\
    jal     ra,outbyte;     \
    addi	a0,zero,'R';	\
    jal     ra,outbyte;     \
	addi	a0,zero,'\n';	\
    jal     ra,outbyte;     \
	ebreak;

#define RVTEST_CODE_END
#define RVTEST_DATA_BEGIN .balign 4;
#define RVTEST_DATA_END

#endif

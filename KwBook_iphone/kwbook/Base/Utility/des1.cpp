#include <stdio.h>
#include "base64_.h"
#include "string.h"
#include "des1.h"
/* DES VERSION 0.4 CREATED BY SIMPLE SOURCE AT 2007.3 */

/* COMPETENCE :

* P4 3.0G 512M

* 3000000 TIMES ENCRYPTION WITH CREATED SUBKEYS

* 26.784 SECONDS (ABOUT 0.85M/S)*/

static int64_t g_arrayMask[64] =
{
	0x0000000000000001, 0x0000000000000002, 0x0000000000000004, 0x0000000000000008,
	0x0000000000000010, 0x0000000000000020, 0x0000000000000040, 0x0000000000000080,
	0x0000000000000100, 0x0000000000000200, 0x0000000000000400, 0x0000000000000800,
	0x0000000000001000, 0x0000000000002000, 0x0000000000004000, 0x0000000000008000,
	0x0000000000010000, 0x0000000000020000, 0x0000000000040000, 0x0000000000080000,
	0x0000000000100000, 0x0000000000200000, 0x0000000000400000, 0x0000000000800000,
	0x0000000001000000, 0x0000000002000000, 0x0000000004000000, 0x0000000008000000,
	0x0000000010000000, 0x0000000020000000, 0x0000000040000000, 0x0000000080000000,
	0x0000000100000000LL, 0x0000000200000000LL, 0x0000000400000000LL, 0x0000000800000000LL,
	0x0000001000000000LL, 0x0000002000000000LL, 0x0000004000000000LL, 0x0000008000000000LL,
	0x0000010000000000LL, 0x0000020000000000LL, 0x0000040000000000LL, 0x0000080000000000LL,
	0x0000100000000000LL, 0x0000200000000000LL, 0x0000400000000000LL, 0x0000800000000000LL,
	0x0001000000000000LL, 0x0002000000000000LL, 0x0004000000000000LL, 0x0008000000000000LL,
	0x0010000000000000LL, 0x0020000000000000LL, 0x0040000000000000LL, 0x0080000000000000LL,
	0x0100000000000000LL, 0x0200000000000000LL, 0x0400000000000000LL, 0x0800000000000000LL,
	0x1000000000000000LL, 0x2000000000000000LL, 0x4000000000000000LL, 0x8000000000000000LL
};

static int g_arrayIP[64] =
{
	57, 49, 41, 33, 25, 17,  9,  1,
	59, 51, 43, 35, 27, 19, 11,  3,
	61, 53, 45, 37, 29, 21, 13,  5,
	63, 55, 47, 39, 31, 23, 15,  7,
	56, 48, 40, 32, 24, 16,  8,  0,
	58, 50, 42, 34, 26, 18, 10,  2,
	60, 52, 44, 36, 28, 20, 12,  4,
	62, 54, 46, 38, 30, 22, 14,  6
};

static int g_arrayE[64] =
{
	31,  0,  1,  2,  3,  4, -1, -1,
	3,  4,  5,  6,  7,  8, -1, -1,
	7,  8,  9, 10, 11, 12, -1, -1,
	11, 12, 13, 14, 15, 16, -1, -1,
	15, 16, 17, 18, 19, 20, -1, -1,
	19, 20, 21, 22, 23, 24, -1, -1,
	23, 24, 25, 26, 27, 28, -1, -1,
	27, 28, 29, 30, 31, 30, -1, -1
};
static char g_matrixNSBox[8][64] =
{
	{
		14,  4,  3, 15,  2, 13,  5,  3,
			13, 14,  6,  9, 11,  2,  0,  5,
			4,  1, 10, 12, 15,  6,  9, 10,
			1,  8, 12,  7,  8, 11,  7,  0,
			0, 15, 10,  5, 14,  4,  9, 10,
			7,  8, 12,  3, 13,  1,  3,  6,
			15, 12,  6, 11,  2,  9,  5,  0,
			4,  2, 11, 14,  1,  7,  8, 13
	},
	{
		15,  0,  9,  5,  6, 10, 12,  9,
			8,  7,  2, 12,  3, 13,  5,  2,
			1, 14,  7,  8, 11,  4,  0,  3,
			14, 11, 13,  6,  4,  1, 10, 15,
			3, 13, 12, 11, 15,  3,  6,  0,
			4, 10,  1,  7,  8,  4, 11, 14,
			13,  8,  0,  6,  2, 15,  9,  5,
			7,  1, 10, 12, 14,  2,  5,  9
		},
		{
			10, 13,  1, 11,  6,  8, 11,  5,
				9,  4, 12,  2, 15,  3,  2, 14,
				0,  6, 13,  1,  3, 15,  4, 10,
				14,  9,  7, 12,  5,  0,  8,  7,
				13,  1,  2,  4,  3,  6, 12, 11,
				0, 13,  5, 14,  6,  8, 15,  2,
				7, 10,  8, 15,  4,  9, 11,  5,
				9,  0, 14,  3, 10,  7,  1, 12
		},
		{
			7, 10,  1, 15,  0, 12, 11,  5,
				14,  9,  8,  3,  9,  7,  4,  8,
				13,  6,  2,  1,  6, 11, 12,  2,
				3,  0,  5, 14, 10, 13, 15,  4,
				13,  3,  4,  9,  6, 10,  1, 12,
				11,  0,  2,  5,  0, 13, 14,  2,
				8, 15,  7,  4, 15,  1, 10,  7,
				5,  6, 12, 11,  3,  8,  9, 14
			},
			{
				2,  4,  8, 15,  7, 10, 13,  6,
					4,  1,  3, 12, 11,  7, 14,  0,
					12,  2,  5,  9, 10, 13,  0,  3,
					1, 11, 15,  5,  6,  8,  9, 14,
					14, 11,  5,  6,  4,  1,  3, 10,
					2, 12, 15,  0, 13,  2,  8,  5,
					11,  8,  0, 15,  7, 14,  9,  4,
					12,  7, 10,  9,  1, 13,  6,  3
			},
			{
				12,  9,  0,  7,  9,  2, 14,  1,
					10, 15,  3,  4,  6, 12,  5, 11,
					1, 14, 13,  0,  2,  8,  7, 13,
					15,  5,  4, 10,  8,  3, 11,  6,
					10,  4,  6, 11,  7,  9,  0,  6,
					4,  2, 13,  1,  9, 15,  3,  8,
					15,  3,  1, 14, 12,  5, 11,  0,
					2, 12, 14,  7,  5, 10,  8, 13
				},
				{
					4,  1,  3, 10, 15, 12,  5,  0,
						2, 11,  9,  6,  8,  7,  6,  9,
						11,  4, 12, 15,  0,  3, 10,  5,
						14, 13,  7,  8, 13, 14,  1,  2,
						13,  6, 14,  9,  4,  1,  2, 14,
						11, 13,  5,  0,  1, 10,  8,  3,
						0, 11,  3,  5,  9,  4, 15,  2,
						7,  8, 12, 15, 10,  7,  6, 12
				},
				{
					13,  7, 10,  0,  6,  9,  5, 15,
						8,  4,  3, 10, 11, 14, 12,  5,
						2, 11,  9,  6, 15, 12,  0,  3,
						4,  1, 14, 13,  1,  2,  7,  8,
						1,  2, 12, 15, 10,  4,  0,  3,
						13, 14,  6,  9,  7,  8,  9,  6,
						15,  1,  5, 12,  3, 10, 14,  5,
						8,  7, 11,  0,  4, 13,  2, 11
					},
};

static int g_arrayP[32] =
{
	15,  6, 19, 20, 28, 11, 27, 16,
	0, 14, 22, 25,  4, 17, 30,  9,
	1,  7, 23, 13, 31, 26,  2,  8,
	18, 12, 29,  5, 21, 10,  3, 24
};

static int g_arrayIP_1[64] =
{
	39,  7, 47, 15, 55, 23, 63, 31,
	38,  6, 46, 14, 54, 22, 62, 30,
	37,  5, 45, 13, 53, 21, 61, 29,
	36,  4, 44, 12, 52, 20, 60, 28,
	35,  3, 43, 11, 51, 19, 59, 27,
	34,  2, 42, 10, 50, 18, 58, 26,
	33,  1, 41,  9, 49, 17, 57, 25,
	32,  0, 40,  8, 48, 16, 56, 24
};

static int g_arrayPC_1[56] =
{
	56, 48, 40, 32, 24, 16,  8,
	0, 57, 49, 41, 33, 25, 17,
	9,  1, 58, 50, 42, 34, 26,
	18, 10,  2, 59, 51, 43, 35,
	62, 54, 46, 38, 30, 22, 14,
	6, 61, 53, 45, 37, 29, 21,
	13,  5, 60, 52, 44, 36, 28,
	20, 12,  4, 27, 19, 11,  3
};

static int g_arrayPC_2[64] =
{
	13, 16, 10, 23,  0,  4, -1, -1,
	2, 27, 14,  5, 20,  9, -1, -1,
	22, 18, 11,  3, 25,  7, -1, -1,
	15,  6, 26, 19, 12,  1, -1, -1,
	40, 51, 30, 36, 46, 54, -1, -1,
	29, 39, 50, 44, 32, 47, -1, -1,
	43, 48, 38, 55, 33, 52, -1, -1,
	45, 41, 49, 35, 28, 31, -1, -1
};

static int g_arrayLs[16] = {1, 1, 2, 2, 2, 2, 2, 2, 1, 2, 2, 2, 2, 2, 2, 1};
static int64_t g_arrayLsMask[3] =
{
	0x0000000000000000LL,
	0x0000000000100001LL,
	0x0000000000300003LL
};

#define BitTransform(array, len, source, dest) \
{\
	int64_t bts = source;\
	int bti;\
	dest = 0;\
	for(bti = 0; bti < len; bti++)\
{\
	if(array[bti] >= 0 && (bts & g_arrayMask[array[bti]]))\
{\
	dest |= g_arrayMask[bti];\
	}\
	}\
	}

#define DES_MODE_ENCRYPT        0
#define DES_MODE_DECRYPT        1

void DESSubKeys(int64_t key, int64_t K[16], int mode);

int64_t DES64(int64_t subkeys[16], int64_t data);



void DESSubKeys(int64_t key, int64_t K[16], int mode)
{
	int64_t temp;
	int j;
	/* PC-1变换 */
	BitTransform(g_arrayPC_1, 56, key, temp);
	for(j = 0; j < 16; j++)
	{
		/* 循环左移 */
		{
			int64_t source = temp;
			temp = ((source & g_arrayLsMask[g_arrayLs[j]]) << (28 - g_arrayLs[j])) | ((source & ~g_arrayLsMask[g_arrayLs[j]]) >> g_arrayLs[j]);
		}
		/* PC-2变换 */
		BitTransform(g_arrayPC_2, 64, temp, K[j]);
	}
	if(mode == DES_MODE_DECRYPT) /* 如果解密则反转子密钥顺序 */
	{
		int64_t t;
		for(j = 0; j < 8; j++)
		{
			t = K[j];
			K[j] = K[15 - j];
			K[15 - j] = t;
		}
	}
}

int64_t DES64(int64_t subkeys[16], int64_t data)
{
	static int64_t out;
	//static int64_t source;
	static int64_t L, R;
	static int32_t * pSource;
	static char * pR;
	static int i;
	static int32_t SOut;
	static int32_t t;
	static int sbi;
	pSource = (int32_t *)&out;
	pR = (char *)&R;
	/* IP变换 */
	{
		BitTransform(g_arrayIP, 64, data, out);
	}
	/* 主迭代 */
	{
		//source = out;
		for(i = 0; i < 16; i++)
		{
			R = pSource[1];
			/* F变换开始 */
			{
				/* E变换 */
				{
					BitTransform(g_arrayE, 64, R, R);
				}
				/* 与子密钥异或 */
				R ^= subkeys[i];
				/* S盒变换 */
				{
					SOut = 0;
					for(sbi = 7; sbi >= 0; sbi--)
					{
						SOut <<= 4;
						SOut |= g_matrixNSBox[sbi][pR[sbi]];
					}
					R = SOut;
				}
				/* P变换 */
				{
					BitTransform(g_arrayP, 32, R, R);
				}
			}
			/* f变换完成 */
			L = pSource[0];
			pSource[0] = pSource[1];
			pSource[1] = (int32_t)(L ^ R);
		}
		/* 交换高低32位 */
		{
			t = pSource[0];
			pSource[0] = pSource[1];
			pSource[1] = t;
		}
	}

	/* IP-1变换 */
	{
		BitTransform(g_arrayIP_1, 64, out, out);
	}
	return out;
}

//from ios版酷我音乐盒，赶工期，实在没时间重写
int encode_msg(string& strEncrypted, const char * Key, const char * szSrc)
{
	if(strlen(Key) != 8)
		return -1;

	int64_t key = (int64_t)Key[0] << 8 * 0 | (int64_t)Key[1] << 8 * 1 | (int64_t)Key[2] << 8 * 2 | (int64_t)Key[3] << 8 * 3 | 
		(int64_t)Key[4] << 8 * 4 | (int64_t)Key[5] << 8 * 5 | (int64_t)Key[6] << 8 * 6 | (int64_t)Key[7] << 8 * 7;

	int num = strlen(szSrc) / sizeof(int64_t);
	char * szEncrypt = new char[(num + 1) * sizeof(int64_t) + 1];
	if(szEncrypt == NULL)
		return -1;
	memset(szEncrypt, 0, (num + 1) * sizeof(int64_t) + 1);

	// 子密钥（临时数据）
	int64_t subKey[16];

	// 加密
	//const int64_t * pSrc = (const int64_t *)szSrc;
	int64_t * pSrc = (int64_t*)malloc(sizeof(int64_t) * num+2);
	memcpy(pSrc, szSrc, sizeof(int64_t) * num+2);
	int64_t * pEncyrpt = (int64_t *)szEncrypt;
	::DESSubKeys(key, subKey, DES_MODE_ENCRYPT);
	for(int i = 0; i < num; i ++)
	{
		pEncyrpt[i] = ::DES64(subKey, pSrc[i]);
	}
	//处理结尾处不够8个字节的部分
	int len = strlen(szSrc) / sizeof(char);
	int tail_num = len % sizeof(int64_t);
	const char * szTail = &szSrc[num * sizeof(int64_t)];
	int64_t tail64 = 0;
	for(int i = 0; i < tail_num; i ++)
		tail64 = tail64 | ((int64_t)(szTail[i])) << (i * 8);
	pEncyrpt[num] = ::DES64(subKey, tail64);

	//Base64编码	// bugs!!!      //从酷我音乐盒ios版拿来的代码，不明白这个bugs!!!是什么意思
	char szOut[10240];	//实验性质，需要多大空间需要计算，1024不一定够      //再次表示无语，汗一个
	base64_encode(szEncrypt, (num + 1) * sizeof(int64_t), szOut, 10240);
    szOut[10240-1] = 0;
	strEncrypted = szOut;
	delete[] szEncrypt; //又是delete又是free的。。。重构的话一定记得改掉这个函数
	free(pSrc);
	return strEncrypted.length();
}


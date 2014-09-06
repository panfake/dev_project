//
//  KwDir.h
//  KwSing
//
//  Created by Qian Hu on 12-7-19.
//  Copyright (c) 2012年 酷我音乐. All rights reserved.
//

#ifndef KwSing_KwDir_h
#define KwSing_KwDir_h
#import <Foundation/Foundation.h>
#include <string>
#include <vector>

namespace KwTools {
    namespace Dir
    {
        enum Path_Type
        {
            PATH_HOME,
            PATH_APP,
            PATH_LIBRARY,
            PATH_DUCUMENT,
            PATH_CASHE,
            PATH_LOG,
            PATH_LOCALMUSIC,
            PATH_LYRIC,
            PATH_BKIMAGE,
            PATH_OPUS,
            PATH_MYIMAGE,
            PATH_USER,
            PATH_DATABASE
        };
        
        
        BOOL GetPath(Path_Type type, std::string &strPath);
        BOOL MakeDir(const std::string& strDir);
        BOOL DeleteDir(const std::string& strDirPath);
        UInt32 GetFileSize(const std::string& strFile);
        BOOL DeleteFile(const std::string& strFile);
        BOOL IsExistFile(const std::string& strfile);
        std::string GetFileName(const std::string& strFilePath);
        std::string GetFileNameWithoutExt(const std::string& strFile);
        std::string GetFilePath(const std::string& strFileFullPathName);
        std::string GetFileExt(const std::string& strFileFullPathName);
        BOOL CopyDir(const std::string& strSrcPath,const std::string& strDstPath);
        BOOL FindFiles(const std::string& strDir,const std::string& strExt,std::vector<std::string>& vecFiles);
        BOOL MoveFile(const std::string& strSrc,const std::string& strDst);

        NSString * GetPath(Path_Type type);
        BOOL MakeDir(NSString* strDir);
        BOOL DeleteDir(NSString* strDirPath);
        UInt32 GetFileSize(NSString* file);
        BOOL DeleteFile(NSString * filepath);
        BOOL IsExistFile(NSString * filepath);
        NSString* GetFileName(NSString* filepath);
        NSString* GetFileNameWithoutExt(NSString* filepath);
        NSString* GetFilePath(NSString* filefullpathname);
        NSString* GetFileExt(NSString* filefullpathname);
        BOOL CopyDir(NSString * srcPath,NSString *dstPath);
        BOOL FindFiles(NSString* strDir,NSString* strExt,NSMutableArray* arrayFiles);
        BOOL MoveFile(NSString* strSrc,NSString* strDst);
        
        int GetFileCount(const std::string & strDir);
        
        bool SkipBackupDirectory(NSString* str_path);
    }
}

#endif

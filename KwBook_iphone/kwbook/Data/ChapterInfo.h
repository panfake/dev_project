//
//  ChapterInfo.h
//  kwbook
//
//  Created by 单 永杰 on 13-11-29.
//  Copyright (c) 2013年 单 永杰. All rights reserved.
//

#ifndef kwbook_ChapterInfo_h
#define kwbook_ChapterInfo_h

#include<string>

class CChapterInfo {
public:
    CChapterInfo();
    virtual~ CChapterInfo(){};
    void LoadFromDict(NSDictionary* dict);
    void SaveToDict(NSMutableDictionary* dict);
    
public:
    std::string m_strBookId;
    std::string m_strName;
    std::string m_strBookName;
    std::string m_strArtist;
    unsigned m_unRid;
    unsigned m_unHotIndex;
    unsigned m_unDownload;     //是否处于下载队列
    unsigned m_unFileSize;     //文件大小，字节
    unsigned m_unDuration;
    std::string m_strUrl;         //播放url
    std::string m_strSig;         //断点续传用
    std::string m_strLocalPath;   //本地缓存
    unsigned m_unLocalSize;    //已缓存大小
};

#endif

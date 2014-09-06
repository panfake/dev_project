//
//  HotSearchWords.cpp
//  kwbook
//
//  Created by 单 永杰 on 13-12-5.
//  Copyright (c) 2013年 单 永杰. All rights reserved.
//

#include "HotSearchWords.h"
#include "KwTools.h"
#include "MessageManager.h"
#include "HttpRequest.h"
#include "SBJson4Parser.h"

#define FILENAME_HOT_SEARCH_WORDS        @"hotSearchWords.plist"

#define URL_HOT_WORDS "http://tingshu.kuwo.cn/tingshu/mobile/GetHotTingshuHotServlet?stype=json&srcver=storynew&type=search_hot&pn=1&ps=50"

static KwTools::CLock S_SEARCH_WORDS_LOCK;

CHotSearchWords::CHotSearchWords(){
    NSString *filepath = KwTools::Dir::GetPath(KwTools::Dir::PATH_DUCUMENT);
    NSString *str = [filepath stringByAppendingPathComponent:FILENAME_HOT_SEARCH_WORDS];
    
    if (KwTools::Dir::IsExistFile(str)) {
        m_arrySearchWords = [[NSMutableArray alloc] initWithContentsOfFile:str];
    }else {
        m_arrySearchWords = [[NSMutableArray alloc] init];
    }
    
//    CHttpRequest* request = new CHttpRequest(URL_HOT_WORDS);
//    request->SetTimeOut(5000);
//    BOOL res = request->SyncSendRequest();
    void * buf(NULL);
    unsigned l(0);
    bool res = CHttpRequest::QuickSyncGet(URL_HOT_WORDS, buf, l);

    if (res) {
        //请求成功
        NSData *retData=[NSData dataWithBytesNoCopy:buf length:l freeWhenDone:YES];
        
        SBJson4ValueBlock block = ^(id item, BOOL *stop){
            NSDictionary *dic = item;
            
            NSArray *array = [dic objectForKey:@"list"];
            if ([array count]) {
                KwTools::CAutoLock auto_lock(&S_SEARCH_WORDS_LOCK);
                
                [m_arrySearchWords removeAllObjects];
                for (NSDictionary *itemDic in array) {
                    [m_arrySearchWords addObject:[itemDic objectForKey:@"name"]];
                }
                
                if(KwTools::Dir::IsExistFile([str UTF8String]))
                {
                    KwTools::Dir::DeleteFile(str);
                }
                [m_arrySearchWords writeToFile:str atomically:YES];
            }
            
        };
        SBJson4ErrorBlock eh = ^(NSError *error){
            NSLog(@"parser json error:%@",error);
        };
        SBJson4Parser *parser = [SBJson4Parser parserWithBlock:block allowMultiRoot:NO unwrapRootArray:NO errorHandler:eh];
        [parser parse:retData];
    }
}

CHotSearchWords* CHotSearchWords::GetInstance(){
    static CHotSearchWords s_hot_search_words;
    
    return &s_hot_search_words;
}

NSArray* CHotSearchWords::GetHotSearchWords(){
    KwTools::CAutoLock auto_lock(&S_SEARCH_WORDS_LOCK);
    
    return m_arrySearchWords;
}

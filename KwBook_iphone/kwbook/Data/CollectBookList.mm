//
//  CollectBookList.cpp
//  kwbook
//
//  Created by 单 永杰 on 13-12-9.
//  Copyright (c) 2013年 单 永杰. All rights reserved.
//

#include "CollectBookList.h"
#include "KwTools.h"
#include "MessageManager.h"
#include "IObserverAudioPlayState.h"

#define FILENAME_COLLECT_BOOKS        @"collectbook.plist"


CCollectBookList::CCollectBookList(){
    LoadAllBooks();
}

CCollectBookList * CCollectBookList::GetInstance(){
    static CCollectBookList sInstance;
    
    return &sInstance;
}

void CCollectBookList::AddBookInfo(CCollectBookInfo* recent_book){
    CCollectBookInfo* book_info = GetCurBook([[NSString stringWithFormat:@"%s", recent_book->m_strBookId.c_str()] intValue]);
    if (book_info) {
        return;
    }else {
        CCollectBookInfo* cur_book = new CCollectBookInfo;
        *((CCollectBookInfo*)cur_book) = *recent_book;
        m_vecCollectList.push_back(cur_book);
    }
    
    SaveAllBooks();
    
    SYN_NOTIFY(OBSERVER_ID_PLAY_STATE, IObserverAudioPlayState::CollectListChanged, [[NSString stringWithUTF8String:recent_book->m_strBookId.c_str()] intValue]);
}

CCollectBookInfo* CCollectBookList::GetCurBook(const unsigned& un_book_id){
    for (std::vector<CCollectBookInfo *>::iterator iter = m_vecCollectList.begin(); iter!= m_vecCollectList.end(); iter++) {
        if(un_book_id == [[NSString stringWithFormat:@"%s", (*iter)->m_strBookId.c_str()] intValue])
            return (*iter);
    }
    
    return NULL;
}

void CCollectBookList::DeleteBookInfo(const unsigned& un_book_id){
    
    CCollectBookInfo* book_info = GetCurBook(un_book_id);
    if (book_info) {
        for (std::vector<CRecentBookInfo *>::iterator iter = m_vecCollectList.begin(); iter!= m_vecCollectList.end(); iter++) {
            if(un_book_id == [[NSString stringWithFormat:@"%s", (*iter)->m_strBookId.c_str()] intValue])
            {
                iter = m_vecCollectList.erase(iter);
                SYN_NOTIFY(OBSERVER_ID_PLAY_STATE, IObserverAudioPlayState::CollectListChanged, (int)un_book_id);
                delete book_info;
                book_info = NULL;
                
                break;
            }
        }
    }
    
    SaveAllBooks();
}

BOOL CCollectBookList::SaveAllBooks(){
    NSMutableArray *arrTask = [NSMutableArray arrayWithCapacity:m_vecCollectList.size()];
    for (std::vector<CCollectBookInfo *>::iterator iter = m_vecCollectList.begin(); iter!= m_vecCollectList.end(); iter++) {
        CCollectBookInfo* temp = ((CCollectBookInfo*)(*iter));
        NSMutableDictionary *dict = [[NSMutableDictionary alloc]init];
        temp->SaveToDict(dict);
        [arrTask addObject:dict];
    }
    
    NSString *filepath = KwTools::Dir::GetPath(KwTools::Dir::PATH_DUCUMENT);
    NSString *str = [filepath stringByAppendingPathComponent:FILENAME_COLLECT_BOOKS];
    if(KwTools::Dir::IsExistFile([str UTF8String]) && !KwTools::Dir::DeleteFile(str))
    {
        return false;
    }
    BOOL bret = [arrTask writeToFile:str atomically:YES];
    
    return bret;
}

BOOL CCollectBookList::LoadAllBooks(){
    m_vecCollectList.clear();
    NSString *filepath = KwTools::Dir::GetPath(KwTools::Dir::PATH_DUCUMENT);
    filepath = [filepath stringByAppendingPathComponent:FILENAME_COLLECT_BOOKS];
    NSMutableArray *arrLocalTask;
    if(KwTools::Dir::IsExistFile(filepath))
    {
        arrLocalTask = [NSMutableArray arrayWithContentsOfFile:filepath];
        for (NSDictionary *dict in arrLocalTask)
        {
            CCollectBookInfo * bookInfo = new CCollectBookInfo;
            ((CCollectBookInfo*)bookInfo)->LoadFromDict(dict);
            
            m_vecCollectList.push_back(bookInfo);
        }
    }
    
    return TRUE;
}


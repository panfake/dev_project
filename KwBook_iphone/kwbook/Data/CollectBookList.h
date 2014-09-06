//
//  CollectBookList.h
//  kwbook
//
//  Created by 单 永杰 on 13-12-9.
//  Copyright (c) 2013年 单 永杰. All rights reserved.
//

#ifndef __kwbook__CollectBookList__
#define __kwbook__CollectBookList__

#include <iostream>
#include <vector>
#include "RecentBookInfo.h"

typedef CRecentBookInfo CCollectBookInfo;

class CCollectBookList {
    
public:
    virtual ~CCollectBookList(){}
    static CCollectBookList * GetInstance();
    void AddBookInfo(CCollectBookInfo* recent_book);
    void DeleteBookInfo(const unsigned& un_book_id);
    CCollectBookInfo* GetCurBook(const unsigned& un_book_id);
    
    std::vector<CCollectBookInfo*>& GetLocalBookVec()
    {
        return m_vecCollectList;
    }
    
    BOOL SaveAllBooks();
private:
    std::vector<CCollectBookInfo *> m_vecCollectList;
private:
    CCollectBookList();
    
    BOOL LoadAllBooks();
    
};

#endif /* defined(__kwbook__CollectBookList__) */

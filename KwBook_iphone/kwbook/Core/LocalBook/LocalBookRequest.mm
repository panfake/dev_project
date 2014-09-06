 //
//  LocalBookRequest.cpp
//  kwbook
//
//  Created by 单 永杰 on 13-12-2.
//  Copyright (c) 2013年 单 永杰. All rights reserved.
//

#include "LocalBookRequest.h"
#include "MessageManager.h"
#include "IObserverDownTaskStatus.h"
#include "KwTools.h"
#include "PlayBookList.h"
#include "BookManagement.h"
#include "KBDatabaseManagement.h"
#include <sstream>
#include "KwConfigElements.h"
#include "KwConfig.h"

#define DOWN_MUSIC_RETRY_COUNT             0

static bool s_b_flow_protect_pause = false;

CLocalBookRequest * CLocalBookRequest::GetInstance()
{
    static CLocalBookRequest sInstance;
    return &sInstance;
}

CLocalBookRequest::CLocalBookRequest()
{
    m_pCurrentTask = NULL;
    m_bChangeData = FALSE;
    GLOBAL_ATTACH_MESSAGE(OBSERVER_ID_APP,IObserverApp);
    GLOBAL_ATTACH_MESSAGE(OBSERVER_ID_FLOW_PROTECT, IObserverFlowProtect);
}

CLocalBookRequest::~CLocalBookRequest()
{
    GLOBAL_DETACH_MESSAGE(OBSERVER_ID_APP,IObserverApp);
    GLOBAL_DETACH_MESSAGE(OBSERVER_ID_FLOW_PROTECT, IObserverFlowProtect);
}

BOOL CLocalBookRequest::StartDownTask(CChapterInfo * chapterInfo)
{
    CChapterInfo cur_chapter = *chapterInfo;
    cur_chapter.m_strLocalPath = [KwTools::Dir::GetPath(KwTools::Dir::PATH_LOCALMUSIC) UTF8String];
    cur_chapter.m_strLocalPath += [[NSString stringWithFormat:@"/%d.m4a", cur_chapter.m_unRid] UTF8String];
    if (KwTools::Dir::IsExistFile(cur_chapter.m_strLocalPath) && !CBookManagement::GetInstance()->HasChapter(chapterInfo->m_unRid)) {
        CLocalTask* localinfo = new CLocalTask;
        
        *((CChapterInfo*)localinfo) = cur_chapter;
        localinfo->m_unDownload = 1;
        localinfo->taskStatus = TaskStatus_Finish;
        CBookManagement::GetInstance()->AddChapter(localinfo);
        [[KBDatabaseManagement sharedInstance] addChapter:localinfo];
        SYN_NOTIFY(OBSERVER_ID_DOWN_STATE, IObserverDownTaskStatus::DownStatusTaskFinish,localinfo->m_unRid);
        
        delete localinfo;
        localinfo = NULL;
        
        return YES;
    }
    
    CChapterInfo *temp_chapter = CBookManagement::GetInstance()->GetChapterInfo(chapterInfo->m_strBookId, chapterInfo->m_unRid);
    if (NULL != temp_chapter) {
        if (0 != temp_chapter->m_unFileSize && temp_chapter->m_unFileSize == temp_chapter->m_unLocalSize) {
            std::string str_dest_path = [KwTools::Dir::GetPath(KwTools::Dir::PATH_LOCALMUSIC) UTF8String];
            str_dest_path += [[NSString stringWithFormat:@"/%d.m4a", temp_chapter->m_unRid] UTF8String];
            KwTools::Dir::MoveFile(temp_chapter->m_strLocalPath, str_dest_path);
            temp_chapter->m_strLocalPath = str_dest_path;
            ((CLocalTask*)temp_chapter)->taskStatus = TaskStatus_Finish;
            SYN_NOTIFY(OBSERVER_ID_DOWN_STATE, IObserverDownTaskStatus::DownStatusTaskFinish,temp_chapter->m_unRid);
            
            return YES;
        }
    }
    CLocalTask * localinfo = (CLocalTask*)CBookManagement::GetInstance()->GetChapterInfo(chapterInfo->m_strBookId, chapterInfo->m_unRid);
    if(localinfo)
    {
        if (localinfo->taskStatus == TaskStatus_Waiting) {
            return  false;
        }
        else if(localinfo->taskStatus == TaskStatus_Downing)
        {
            return FALSE;
        }
        else if(localinfo->taskStatus == TaskStatus_Finish)
        {
            return FALSE;
        }
        else if(localinfo->taskStatus == TaskStatus_Pause)
        {
            localinfo->taskStatus = TaskStatus_Waiting;
            SYN_NOTIFY(OBSERVER_ID_DOWN_STATE, IObserverDownTaskStatus::DownStatusTaskStart,localinfo->m_unRid);
        }else if(localinfo->taskStatus == TaskStatus_Fail)
        {
            KwTools::Dir::DeleteFile(localinfo->m_strLocalPath);
            localinfo->taskStatus = TaskStatus_Waiting;
            SYN_NOTIFY(OBSERVER_ID_DOWN_STATE, IObserverDownTaskStatus::DownStatusTaskStart,localinfo->m_unRid);
        }
    }
    else {
        localinfo = new CLocalTask;
        
        *((CChapterInfo*)localinfo) = *chapterInfo;
        localinfo->m_unDownload = 0;
        localinfo->taskStatus = TaskStatus_Waiting;
        
        CBookManagement::GetInstance()->AddChapter(localinfo);
        [[KBDatabaseManagement sharedInstance] addChapter:localinfo];
        
        SYN_NOTIFY(OBSERVER_ID_DOWN_STATE, IObserverDownTaskStatus::DownStatusAddTask,localinfo->m_unRid);
        
        delete localinfo;
        localinfo = NULL;
    }
    
    UpdateDownTask();
    return TRUE;
}

BOOL CLocalBookRequest::AddWaitingTask(CChapterInfo *chapterInfo){
    CChapterInfo cur_chapter = *chapterInfo;
    cur_chapter.m_strLocalPath = [KwTools::Dir::GetPath(KwTools::Dir::PATH_LOCALMUSIC) UTF8String];
    cur_chapter.m_strLocalPath += [[NSString stringWithFormat:@"/%d.m4a", cur_chapter.m_unRid] UTF8String];
    if (KwTools::Dir::IsExistFile(cur_chapter.m_strLocalPath) && !CBookManagement::GetInstance()->HasChapter(chapterInfo->m_unRid)) {
        CLocalTask* localinfo = new CLocalTask;
        
        *((CChapterInfo*)localinfo) = cur_chapter;
        localinfo->m_unDownload = 1;
        localinfo->taskStatus = TaskStatus_Finish;
        CBookManagement::GetInstance()->AddChapter(localinfo);
        [[KBDatabaseManagement sharedInstance] addChapter:localinfo];
        SYN_NOTIFY(OBSERVER_ID_DOWN_STATE, IObserverDownTaskStatus::DownStatusTaskFinish,localinfo->m_unRid);
        
        delete localinfo;
        localinfo = NULL;
        
        return YES;
    }
    
    CChapterInfo *temp_chapter = CBookManagement::GetInstance()->GetChapterInfo(chapterInfo->m_strBookId, chapterInfo->m_unRid);
    if (NULL != temp_chapter) {
        if (0 != temp_chapter->m_unFileSize && temp_chapter->m_unFileSize == temp_chapter->m_unLocalSize) {
            std::string str_dest_path = [KwTools::Dir::GetPath(KwTools::Dir::PATH_LOCALMUSIC) UTF8String];
            str_dest_path += [[NSString stringWithFormat:@"/%d.m4a", temp_chapter->m_unRid] UTF8String];
            KwTools::Dir::MoveFile(temp_chapter->m_strLocalPath, str_dest_path);
            temp_chapter->m_strLocalPath = str_dest_path;
            ((CLocalTask*)temp_chapter)->taskStatus = TaskStatus_Finish;
            SYN_NOTIFY(OBSERVER_ID_DOWN_STATE, IObserverDownTaskStatus::DownStatusTaskFinish,temp_chapter->m_unRid);
            
            return YES;
        }
    }
    CLocalTask * localinfo = (CLocalTask*)CBookManagement::GetInstance()->GetChapterInfo(chapterInfo->m_strBookId, chapterInfo->m_unRid);
    if(localinfo)
    {
        return TRUE;
    }
    else {
        localinfo = new CLocalTask;
        
        *((CChapterInfo*)localinfo) = *chapterInfo;
        localinfo->m_unDownload = 0;
        localinfo->taskStatus = TaskStatus_Pause;
        
        CBookManagement::GetInstance()->AddChapter(localinfo);
        [[KBDatabaseManagement sharedInstance] addChapter:localinfo];
        
        SYN_NOTIFY(OBSERVER_ID_DOWN_STATE, IObserverDownTaskStatus::DownStatusAddTask,localinfo->m_unRid);
        
        delete localinfo;
        localinfo = NULL;
    }

    return TRUE;
}

BOOL CLocalBookRequest::StartDownTasks(std::vector<CChapterInfo*>& vec_chapters){
//    std::vector<CChapterInfo*> temp_vec_chapters = vec_chapters;
    for (std::vector<CChapterInfo*>::iterator iter = vec_chapters.begin(); iter != vec_chapters.end();){
        if (CBookManagement::GetInstance()->HasChapter((*iter)->m_unRid)) {
            iter = vec_chapters.erase(iter);
        }else {
            ++iter;
        }
    }

//    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
    [[KBDatabaseManagement sharedInstance] addChapters:vec_chapters];
//    });
    
    for (std::vector<CChapterInfo*>::iterator iter = vec_chapters.begin(); iter != vec_chapters.end(); ++iter) {
        (*iter)->m_unDownload = 0;
        CChapterInfo* cur_chapter = *iter;
        cur_chapter->m_strLocalPath = [KwTools::Dir::GetPath(KwTools::Dir::PATH_LOCALMUSIC) UTF8String];
        cur_chapter->m_strLocalPath += [[NSString stringWithFormat:@"/%d.m4a", cur_chapter->m_unRid] UTF8String];
        if (KwTools::Dir::IsExistFile(cur_chapter->m_strLocalPath) && !CBookManagement::GetInstance()->GetChapterInfo(cur_chapter->m_strBookId, cur_chapter->m_unRid)) {
            CLocalTask* localinfo = new CLocalTask;
            
            *((CChapterInfo*)localinfo) = *cur_chapter;
            localinfo->m_unDownload = 1;
            localinfo->taskStatus = TaskStatus_Finish;
            CBookManagement::GetInstance()->AddChapter(localinfo);
            [[KBDatabaseManagement sharedInstance] updateChapter:localinfo];
            SYN_NOTIFY(OBSERVER_ID_DOWN_STATE, IObserverDownTaskStatus::DownStatusTaskFinish,localinfo->m_unRid);
            
            delete localinfo;
            localinfo = NULL;
            
            continue;
        }
        
        CChapterInfo *temp_chapter = CBookManagement::GetInstance()->GetChapterInfo((*iter)->m_strBookId, (*iter)->m_unRid);
        if (NULL != temp_chapter) {
            if (0 != temp_chapter->m_unFileSize && temp_chapter->m_unFileSize == temp_chapter->m_unLocalSize) {
                std::string str_dest_path = [KwTools::Dir::GetPath(KwTools::Dir::PATH_LOCALMUSIC) UTF8String];
                str_dest_path += [[NSString stringWithFormat:@"/%d.m4a", temp_chapter->m_unRid] UTF8String];
                KwTools::Dir::MoveFile(temp_chapter->m_strLocalPath, str_dest_path);
                temp_chapter->m_strLocalPath = str_dest_path;
                temp_chapter->m_unDownload = 1;
                ((CLocalTask*)temp_chapter)->taskStatus = TaskStatus_Finish;
                
                [[KBDatabaseManagement sharedInstance] updateChapter:temp_chapter];
                
                SYN_NOTIFY(OBSERVER_ID_DOWN_STATE, IObserverDownTaskStatus::DownStatusTaskFinish,temp_chapter->m_unRid);
                
                continue;
            }
        }
        CLocalTask * localinfo = (CLocalTask*)CBookManagement::GetInstance()->GetChapterInfo((*iter)->m_strBookId, (*iter)->m_unRid);
        if(localinfo)
        {
            if (localinfo->taskStatus == TaskStatus_Waiting) {
                continue;
            }
            else if(localinfo->taskStatus == TaskStatus_Downing)
            {
                continue;
            }
            else if(localinfo->taskStatus == TaskStatus_Finish)
            {
                //            SYN_NOTIFY(OBSERVER_ID_MUSICLIB, IMusicLibObserver::RecordMusic,localinfo->strRid);
                continue;
            }
            else if(localinfo->taskStatus == TaskStatus_Pause)
            {
                localinfo->taskStatus = TaskStatus_Waiting;
                SYN_NOTIFY(OBSERVER_ID_DOWN_STATE, IObserverDownTaskStatus::DownStatusTaskStart,localinfo->m_unRid);
            }else if(localinfo->taskStatus == TaskStatus_Fail)
            {
                KwTools::Dir::DeleteFile(localinfo->m_strLocalPath);
                localinfo->taskStatus = TaskStatus_Waiting;
                SYN_NOTIFY(OBSERVER_ID_DOWN_STATE, IObserverDownTaskStatus::DownStatusTaskStart,localinfo->m_unRid);
            }
        }
        else {
            //        c_KuwoDebugLog("LOCALMUSIC",DEBUG_LOG,"StartDownTask:New Task is created:rid=%s",songInfo->strRid.c_str());
            localinfo = new CLocalTask;
            
            *((CChapterInfo*)localinfo) = **iter;
            localinfo->m_unDownload = 0;
            localinfo->taskStatus = TaskStatus_Waiting;
            CBookManagement::GetInstance()->AddChapter(localinfo);
//            [[KBDatabaseManagement sharedInstance] updateChapter:localinfo];
            
//            SYN_NOTIFY(OBSERVER_ID_DOWN_STATE, IObserverDownTaskStatus::DownStatusAddTask,localinfo->m_unRid);
            
            delete localinfo;
            localinfo = NULL;
        }
    }
    SYN_NOTIFY(OBSERVER_ID_DOWN_STATE, IObserverDownTaskStatus::DownStatusAddTasksFinish);
    
    UpdateDownTask();
    
    return YES;
}

BOOL CLocalBookRequest::AddWaitingTasks(std::vector<CChapterInfo *> &vec_chapters){
    for (std::vector<CChapterInfo*>::iterator iter = vec_chapters.begin(); iter != vec_chapters.end();){
        if (CBookManagement::GetInstance()->HasChapter((*iter)->m_unRid)) {
            iter = vec_chapters.erase(iter);
        }else {
            ++iter;
        }
    }
    
    //    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
    [[KBDatabaseManagement sharedInstance] addChapters:vec_chapters];
    //    });
    
    for (std::vector<CChapterInfo*>::iterator iter = vec_chapters.begin(); iter != vec_chapters.end(); ++iter) {
        (*iter)->m_unDownload = 0;
        CChapterInfo* cur_chapter = *iter;
        cur_chapter->m_strLocalPath = [KwTools::Dir::GetPath(KwTools::Dir::PATH_LOCALMUSIC) UTF8String];
        cur_chapter->m_strLocalPath += [[NSString stringWithFormat:@"/%d.m4a", cur_chapter->m_unRid] UTF8String];
        if (KwTools::Dir::IsExistFile(cur_chapter->m_strLocalPath) && !CBookManagement::GetInstance()->GetChapterInfo(cur_chapter->m_strBookId, cur_chapter->m_unRid)) {
            CLocalTask* localinfo = new CLocalTask;
            
            *((CChapterInfo*)localinfo) = *cur_chapter;
            localinfo->m_unDownload = 1;
            localinfo->taskStatus = TaskStatus_Finish;
            CBookManagement::GetInstance()->AddChapter(localinfo);
            [[KBDatabaseManagement sharedInstance] updateChapter:localinfo];
            SYN_NOTIFY(OBSERVER_ID_DOWN_STATE, IObserverDownTaskStatus::DownStatusTaskFinish,localinfo->m_unRid);
            
            delete localinfo;
            localinfo = NULL;
            
            continue;
        }
        
        CChapterInfo *temp_chapter = CBookManagement::GetInstance()->GetChapterInfo((*iter)->m_strBookId, (*iter)->m_unRid);
        if (NULL != temp_chapter) {
            if (0 != temp_chapter->m_unFileSize && temp_chapter->m_unFileSize == temp_chapter->m_unLocalSize) {
                std::string str_dest_path = [KwTools::Dir::GetPath(KwTools::Dir::PATH_LOCALMUSIC) UTF8String];
                str_dest_path += [[NSString stringWithFormat:@"/%d.m4a", temp_chapter->m_unRid] UTF8String];
                KwTools::Dir::MoveFile(temp_chapter->m_strLocalPath, str_dest_path);
                temp_chapter->m_strLocalPath = str_dest_path;
                temp_chapter->m_unDownload = 1;
                ((CLocalTask*)temp_chapter)->taskStatus = TaskStatus_Finish;
                
                [[KBDatabaseManagement sharedInstance] updateChapter:temp_chapter];
                
                SYN_NOTIFY(OBSERVER_ID_DOWN_STATE, IObserverDownTaskStatus::DownStatusTaskFinish,temp_chapter->m_unRid);
                
                continue;
            }
        }
        CLocalTask * localinfo = (CLocalTask*)CBookManagement::GetInstance()->GetChapterInfo((*iter)->m_strBookId, (*iter)->m_unRid);
        if(localinfo)
        {
            continue;
        }
        else {
            //        c_KuwoDebugLog("LOCALMUSIC",DEBUG_LOG,"StartDownTask:New Task is created:rid=%s",songInfo->strRid.c_str());
            localinfo = new CLocalTask;
            
            *((CChapterInfo*)localinfo) = **iter;
            localinfo->m_unDownload = 0;
            localinfo->taskStatus = TaskStatus_Waiting;
            CBookManagement::GetInstance()->AddChapter(localinfo);
            //            [[KBDatabaseManagement sharedInstance] updateChapter:localinfo];
            
            SYN_NOTIFY(OBSERVER_ID_DOWN_STATE, IObserverDownTaskStatus::DownStatusAddTask,localinfo->m_unRid);
            
            delete localinfo;
            localinfo = NULL;
        }
    }
    SYN_NOTIFY(OBSERVER_ID_DOWN_STATE, IObserverDownTaskStatus::DownStatusAddTasksFinish);
    
    return YES;
}

void CLocalBookRequest::DownTaskThread(CChapterInfo * pChapterInfo)
{
    std::stringstream str_from_int;
    str_from_int << pChapterInfo->m_unRid;
    std::string strParam="type=convert_url2&network=";
    strParam += CHttpRequest::GetNetWorkStatus()==NETSTATUS_WIFI?"WIFI":"3G";
    //        strParam += "&format=mp3&mode=audition&rid="+para.strRid;
    strParam += "&format=aac&mode=download&br=48kaac&rid=";
    strParam += str_from_int.str();
    
    std::string strEncryptParam=KwTools::Encrypt::CreateDesUrl(strParam);
    
    bool bret = false;
    std::string strData = "";
    
    if(!(pChapterInfo->m_unFileSize && pChapterInfo->m_unFileSize == pChapterInfo->m_unLocalSize))
    {
        bret = CHttpRequest::QuickSyncGet(strEncryptParam, strData);
        if (bret && !strData.empty()) {
            std::map<std::string,std::string> mapDatas;
            KwTools::StringUtility::TokenizeKeyValueEx(strData,mapDatas,"\r\n");
            if (mapDatas.empty()) {
                
                bret = false;
            }else {
                pChapterInfo->m_strUrl=mapDatas["url"];
                pChapterInfo->m_strLocalPath = [KwTools::Dir::GetPath(KwTools::Dir::PATH_LOCALMUSIC) UTF8String];
                pChapterInfo->m_strLocalPath += [[NSString stringWithFormat:@"/%d.aac", pChapterInfo->m_unRid] UTF8String];
            }
        }
    }
    
    {
        // 以下在主线程中执行
        dispatch_sync(dispatch_get_main_queue(), ^{
            if(m_pCurrentTask && m_pCurrentTask->m_unRid == pChapterInfo->m_unRid)
            {
                if(bret)
                {
                    std::string strlocal;
                    KwTools::Dir::GetPath(KwTools::Dir::PATH_LOCALMUSIC,strlocal);
                    strlocal += "/";
                    strlocal += [[NSString stringWithFormat:@"%d", m_pCurrentTask->m_unRid] UTF8String];
                    std::string strex = pChapterInfo->m_strUrl.substr(pChapterInfo->m_strUrl.rfind("."),-1);
                    m_pCurrentTask->m_strLocalPath = strlocal + strex;
                    
                    m_pCurrentTask->pRequest = new CHttpRequest(pChapterInfo->m_strUrl, m_pCurrentTask->m_strLocalPath);
//                    NSLog(@"cur task sig %d", m_pCurrentTask->m_strSig.length());
                    
                    m_pCurrentTask->pRequest->AsyncSendRequest(this);
                    m_pCurrentTask->downStatus = Status_DowningBook;
                    m_pCurrentTask->taskStatus = TaskStatus_Downing;
                    SYN_NOTIFY(OBSERVER_ID_DOWN_STATE, IObserverDownTaskStatus::DownStatusTaskStart,m_pCurrentTask->m_unRid);
                }
                else {
                    // 失败的任务从下载队列中删除
                    //DeleteTask(m_pCurrentTask->strRid);
                    m_pCurrentTask->taskStatus = TaskStatus_Fail;
//                    SYN_NOTIFY(OBSERVER_ID_MUSICLIB, IMusicLibObserver::TaskFail,m_pCurrentTask->strRid);
                    SYN_NOTIFY(OBSERVER_ID_DOWN_STATE, IObserverDownTaskStatus::DownStatustaskFail,m_pCurrentTask->m_unRid);
                    m_pCurrentTask = NULL;
                    UpdateDownTask();
                }
            }
        });
    }
}

BOOL CLocalBookRequest::HasDowningTask()
{
    return (NULL != m_pCurrentTask) ? TRUE : FALSE;
}

/*void CLocalBookRequest::ClearBuffer(){
    NSMutableArray* arrayFiles = [[NSMutableArray alloc] init];
    KwTools::Dir::FindFiles([NSString stringWithFormat:@"%@/", KwTools::Dir::GetPath(KwTools::Dir::PATH_LOCALMUSIC)], @"m4a", arrayFiles);
    
    int n_count = arrayFiles.count;
    for (int n_itr = 0; n_itr < n_count; ++n_itr) {
        NSString* str_file_path = [arrayFiles objectAtIndex:n_itr];
        NSString* str_file_name = KwTools::Dir::GetFileName(str_file_path);
        NSString* str_rid = KwTools::Dir::GetFileNameWithoutExt(str_file_name);
        if (NULL == GetLocalBook([str_rid intValue])) {
            KwTools::Dir::DeleteDir(str_file_path);
        }
    }
}
*/
void CLocalBookRequest::IHttpNotify_DownStart(CHttpRequest* pRequest,long lTotalSize)
{
    if(m_pCurrentTask && m_pCurrentTask->pRequest && m_pCurrentTask->pRequest == pRequest)
    {
        if(m_pCurrentTask->downStatus == Status_DowningBook)
            m_pCurrentTask->m_unFileSize = lTotalSize;
        m_bChangeData = true;
    }
    
}

void CLocalBookRequest::IHttpNotify_Process(CHttpRequest* pRequest,long lTotalSize,long lCurrentSize,long lSpeed)
{
    if(CHttpRequest::GetNetWorkStatus() == NETSTATUS_NONE)
        return;
    if(m_pCurrentTask && m_pCurrentTask->pRequest && m_pCurrentTask->pRequest == pRequest)
    {
        if(lCurrentSize == 0)
            return;
        if(lTotalSize<lCurrentSize)
            return;
        float fpercent = 0;
        if(m_pCurrentTask->downStatus == Status_DowningBook)
        {
            m_pCurrentTask->m_unFileSize = lTotalSize;
            m_pCurrentTask->m_unLocalSize = lCurrentSize;
            fpercent = lCurrentSize*1.0/lTotalSize;
        }
        
        CChapterInfo* book_info = CBookManagement::GetInstance()->GetChapterInfo(m_pCurrentTask->m_strBookId, m_pCurrentTask->m_unRid);
        if (book_info) {
            book_info->m_unLocalSize = lCurrentSize;
        }
        
        m_bChangeData = true;
        
        SYN_NOTIFY(OBSERVER_ID_DOWN_STATE, IObserverDownTaskStatus::DownStatusTaskProgress,m_pCurrentTask->m_unRid, fpercent, (lCurrentSize * 1.0 / (1024 * 1024)), (lTotalSize * 1.0 / (1024 * 1024)));
    }
}

void CLocalBookRequest::IHttpNotify_Stop(CHttpRequest* pRequest,BOOL bSuccess)
{
    if(m_pCurrentTask && m_pCurrentTask->pRequest && m_pCurrentTask->pRequest == pRequest)
    {
        if(bSuccess)
        {
            if(m_pCurrentTask->downStatus == Status_DowningBook)
            {
                CLocalTask * localinfo = (CLocalTask*)CBookManagement::GetInstance()->GetChapterInfo(m_pCurrentTask->m_strBookId, m_pCurrentTask->m_unRid);
                localinfo->nRetryCount = 0;
                localinfo->taskStatus = TaskStatus_Finish;
                localinfo->m_unFileSize = m_pCurrentTask->m_unFileSize;
                localinfo->m_unLocalSize = m_pCurrentTask->m_unFileSize;
                localinfo->m_unDownload = 1;
                
                std::string str_filename_src = m_pCurrentTask->m_strLocalPath;
                std::string str_filepath_dest = KwTools::Dir::GetFilePath(str_filename_src);

                NSString* nsstr_filePathDest = [NSString stringWithFormat:@"%s.m4a", str_filepath_dest.c_str()];
                localinfo->m_strLocalPath = [nsstr_filePathDest UTF8String];
                
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    [[KBDatabaseManagement sharedInstance] updateChapter:localinfo];
                });
                
                if (KwTools::Dir::IsExistFile(localinfo->m_strLocalPath)) {
                    KwTools::Dir::DeleteFile(str_filename_src);
                }else {
                    KwTools::Dir::MoveFile(str_filename_src, localinfo->m_strLocalPath);
                }
                
                SYN_NOTIFY(OBSERVER_ID_DOWN_STATE, IObserverDownTaskStatus::DownStatusTaskFinish,localinfo->m_unRid);
            }
        }
        else
        {
            KwTools::Dir::DeleteFile(m_pCurrentTask->m_strLocalPath);
            m_pCurrentTask->m_unLocalSize = 0;
            m_pCurrentTask->m_unFileSize = 0;
            m_pCurrentTask->m_strSig = "";
            if(m_pCurrentTask->nRetryCount >= DOWN_MUSIC_RETRY_COUNT)
            {
                // 失败的任务从下载队列中删除
                m_pCurrentTask->taskStatus = TaskStatus_Fail;
                m_pCurrentTask->nRetryCount = 0;
                SYN_NOTIFY(OBSERVER_ID_DOWN_STATE, IObserverDownTaskStatus::DownStatustaskFail,m_pCurrentTask->m_unRid);
            }
            else {
                // 重试
                m_pCurrentTask->nRetryCount++;
            }
        }
        
        if (m_pCurrentTask) {
            m_pCurrentTask->m_unLocalSize = 0;
            m_pCurrentTask->m_unFileSize = 0;
            m_pCurrentTask->pRequest->StopRequest();
            delete m_pCurrentTask->pRequest;
            m_pCurrentTask->pRequest = NULL;
            m_pCurrentTask = NULL;
        }
        
        if (!s_b_flow_protect_pause) {
            UpdateDownTask();
        }else {
            s_b_flow_protect_pause = false;
        }
        
    }
}

BOOL CLocalBookRequest::DeleteTask(CChapterInfo* chapter_info)
{
    if(CBookManagement::GetInstance()->HasChapter(chapter_info->m_unRid))
    {
        bool b_current_task = false;
        if(m_pCurrentTask && m_pCurrentTask->m_unRid == chapter_info->m_unRid)
        {
            b_current_task = true;
            if(m_pCurrentTask->pRequest)
                m_pCurrentTask->pRequest->StopRequest();
            m_pCurrentTask = NULL;
        }
        
        CBookManagement::GetInstance()->DeleteChapter(chapter_info);
        
        if (b_current_task) {
            UpdateDownTask();
        }
        
        SYN_NOTIFY(OBSERVER_ID_DOWN_STATE, IObserverDownTaskStatus::DownStatusDeleteTask);
        return TRUE;
    }
    return  FALSE;
}

BOOL CLocalBookRequest::DeleteTasks(std::string str_book_id){
    bool b_current_task = false;
    if(m_pCurrentTask && m_pCurrentTask->m_strBookId == str_book_id)
    {
        b_current_task = true;
        if(m_pCurrentTask->pRequest)
            m_pCurrentTask->pRequest->StopRequest();
        m_pCurrentTask = NULL;
    }
    
    CBookManagement::GetInstance()->DeleteChapters(str_book_id);
    
    if (b_current_task) {
        UpdateDownTask();
    }
    
    SYN_NOTIFY(OBSERVER_ID_DOWN_STATE, IObserverDownTaskStatus::DownStatusDeleteTasks);
    
    return YES;
}

BOOL CLocalBookRequest::DeleteTasks(std::string str_book_id, bool b_finished){
    if (b_finished) {
        
        CBookManagement::GetInstance()->DeleteChapters(str_book_id, b_finished);
        
        SYN_NOTIFY(OBSERVER_ID_DOWN_STATE, IObserverDownTaskStatus::DownStatusDeleteTasks);
    }else {
        bool b_current_task = false;
        if(m_pCurrentTask && m_pCurrentTask->m_strBookId == str_book_id)
        {
            b_current_task = true;
            if(m_pCurrentTask->pRequest)
                m_pCurrentTask->pRequest->StopRequest();
            m_pCurrentTask = NULL;
        }
        
        CBookManagement::GetInstance()->DeleteChapters(str_book_id, b_finished);
        
        if (b_current_task) {
            UpdateDownTask();
        }
        
        SYN_NOTIFY(OBSERVER_ID_DOWN_STATE, IObserverDownTaskStatus::DownStatusDeleteTasks);
    }
    
    return YES;
}

BOOL CLocalBookRequest::PauseDownTask(CChapterInfo* chapter_info)
{
    CLocalTask* localtask = (CLocalTask*)CBookManagement::GetInstance()->GetChapterInfo(chapter_info->m_strBookId, chapter_info->m_unRid);
    bool b_current_task = false;
    if(m_pCurrentTask && m_pCurrentTask->m_unRid == chapter_info->m_unRid)
    {
        b_current_task = true;
        if(m_pCurrentTask->pRequest)
        {
            m_pCurrentTask->pRequest->StopRequest();
            delete m_pCurrentTask->pRequest;
            m_pCurrentTask->pRequest = NULL;
        }
        m_pCurrentTask = NULL;
    }
    if (localtask) {
        localtask->taskStatus = TaskStatus_Pause;
    }
    
    if (b_current_task) {
        UpdateDownTask();
    }
    
    if (localtask) {
        SYN_NOTIFY(OBSERVER_ID_DOWN_STATE, IObserverDownTaskStatus::DownStatusPauseTask,localtask->m_unRid);
    }
    
    return YES;
}


//更新当前真正下载对象
void CLocalBookRequest::UpdateDownTask()
{
    if(m_pCurrentTask != NULL)
        return;
    
    s_b_flow_protect_pause = false;
    
    std::vector<CBookInfo*> book_list = CBookManagement::GetInstance()->GetBookList();
    for (std::vector<CBookInfo*>::iterator iter_book = book_list.begin(); iter_book != book_list.end(); ++iter_book) {
        std::vector<CChapterInfo*>* chapter_list = CBookManagement::GetInstance()->GetChapterList((*iter_book)->m_strBookId);
        for (std::vector<CChapterInfo*>::iterator iter_chapter = chapter_list->begin(); iter_chapter != chapter_list->end(); ++iter_chapter) {
            if(((CLocalTask*)(*iter_chapter))->taskStatus == TaskStatus_Waiting){
                CChapterInfo *ptemp = new CChapterInfo;
                m_pCurrentTask = (CLocalTask*)(*iter_chapter);
                *ptemp = **iter_chapter;
                KS_BLOCK_DECLARE
                {
                    DownTaskThread(ptemp);
                    delete ptemp;
                }
                KS_BLOCK_RUN_THREAD();
                return;
            }
        }
    }

    SYN_NOTIFY(OBSERVER_ID_DOWN_STATE, IObserverDownTaskStatus::DownStatusAllTaskFinish);
}

BOOL CLocalBookRequest::StartAllTask(std::string str_book_id)
{
    std::vector<CChapterInfo*>* chapter_list = CBookManagement::GetInstance()->GetChapterList(str_book_id);
    for (std::vector<CChapterInfo*>::iterator iter = chapter_list->begin(); iter!= chapter_list->end(); iter++) {
        std::string str_dest_path = [KwTools::Dir::GetPath(KwTools::Dir::PATH_LOCALMUSIC) UTF8String];
        str_dest_path += [[NSString stringWithFormat:@"/%d.m4a", (*iter)->m_unRid] UTF8String];
        if (TaskStatus_Fail == ((CLocalTask*)(*iter))->taskStatus) {
            KwTools::Dir::DeleteFile((*iter)->m_strLocalPath);
            KwTools::Dir::DeleteFile(str_dest_path);
            (*iter)->m_unFileSize = 0;
            (*iter)->m_unLocalSize = 0;
        }
        if (!KwTools::Dir::IsExistFile(str_dest_path) && TaskStatus_Downing != ((CLocalTask*)(*iter))->taskStatus) {
            ((CLocalTask*)(*iter))->taskStatus = TaskStatus_Waiting;
        }
    }
    UpdateDownTask();
    SYN_NOTIFY(OBSERVER_ID_DOWN_STATE, IObserverDownTaskStatus::DownStatusTaskAllStart);
    return TRUE;
}

BOOL CLocalBookRequest::PauseAllTasks(std::string str_book_id)
{
    bool b_current_task = false;
    if(m_pCurrentTask && m_pCurrentTask->m_strBookId == str_book_id && m_pCurrentTask->pRequest)
    {
        b_current_task = true;
        m_pCurrentTask->taskStatus = TaskStatus_Pause;
        m_pCurrentTask->pRequest->StopRequest();
        delete m_pCurrentTask->pRequest;
        m_pCurrentTask->pRequest = NULL;
    }
    m_pCurrentTask = NULL;
    
    std::vector<CChapterInfo*>* chapter_list = CBookManagement::GetInstance()->GetChapterList(str_book_id);
    for (std::vector<CChapterInfo*>::iterator iter = chapter_list->begin(); iter!= chapter_list->end(); iter++) {
        std::string str_dest_path = [KwTools::Dir::GetPath(KwTools::Dir::PATH_LOCALMUSIC) UTF8String];
        str_dest_path += [[NSString stringWithFormat:@"/%d.m4a", (*iter)->m_unRid] UTF8String];
        if (!KwTools::Dir::IsExistFile(str_dest_path) && TaskStatus_Fail != ((CLocalTask*)(*iter))->taskStatus) {
            ((CLocalTask*)(*iter))->taskStatus = TaskStatus_Pause;
        }
    }
    
    if (b_current_task) {
        UpdateDownTask();
    }
    
    SYN_NOTIFY(OBSERVER_ID_DOWN_STATE, IObserverDownTaskStatus::DownStatusPauseAllTasks);
    return TRUE;
}

BOOL CLocalBookRequest::IsLocalChapter(unsigned un_rid)
{
    std::string str_file_path = [KwTools::Dir::GetPath(KwTools::Dir::PATH_LOCALMUSIC) UTF8String];
    str_file_path += [[NSString stringWithFormat:@"/%d.m4a", un_rid] UTF8String];
    
    return KwTools::Dir::IsExistFile(str_file_path);
}

void CLocalBookRequest::IObserverApp_EnterForeground()
{
//    UpdateDownTask();
}

void CLocalBookRequest::IObserverApp_NetWorkStatusChanged(KSNetworkStatus enumStatus)
{
    bool b_flow_protect = false;
    KwConfig::GetConfigureInstance()->GetConfigBoolValue(FLOW_PROTECT_GROUP, FLOW_PROTECT_STATUS, b_flow_protect);
    
    if (!b_flow_protect) {
        return;
    }
    
    switch (enumStatus) {
        case NETSTATUS_WIFI:
        {
            
            
            break;
        }
            
        case NETSTATUS_WWAN:
        {
            if(m_pCurrentTask && m_pCurrentTask->pRequest)
            {
                SYN_NOTIFY(OBSERVER_ID_DOWN_STATE, IObserverDownTaskStatus::DownStatusPauseTask,m_pCurrentTask->m_unRid);
                s_b_flow_protect_pause = true;
                m_pCurrentTask->pRequest->StopRequest();
                m_pCurrentTask->taskStatus = TaskStatus_Pause;
                delete m_pCurrentTask->pRequest;
                m_pCurrentTask->pRequest = NULL;
            }
            m_pCurrentTask = NULL;
            
            break;
        }
        default:
            break;
    }
}

#pragma mark delegate of flow protect status changed

void CLocalBookRequest::IObserverFlowProtectStatusChanged(bool b_protect_on)
{
    if (b_protect_on) {
        if (NETSTATUS_WWAN == CHttpRequest::GetNetWorkStatus()) {
            if(m_pCurrentTask && m_pCurrentTask->pRequest)
            {
                SYN_NOTIFY(OBSERVER_ID_DOWN_STATE, IObserverDownTaskStatus::DownStatusPauseTask,m_pCurrentTask->m_unRid);
                s_b_flow_protect_pause = true;
                m_pCurrentTask->taskStatus = TaskStatus_Pause;
                m_pCurrentTask->pRequest->StopRequest();
                delete m_pCurrentTask->pRequest;
                m_pCurrentTask->pRequest = NULL;
            }
            m_pCurrentTask = NULL;
        }
    }
}

//
//  IObserverDownTaskStatus.h
//  kwbook
//
//  Created by 单 永杰 on 13-12-3.
//  Copyright (c) 2013年 单 永杰. All rights reserved.
//

#ifndef kwbook_IObserverDownTaskStatus_h
#define kwbook_IObserverDownTaskStatus_h

#include "IMessageObserver.h"

@protocol IObserverDownTaskStatus <NSObject>
@optional
-(void)IObDownStatus_AddTask:(unsigned)un_rid;
-(void)IObDownStatus_DownTaskFinish:(unsigned)un_rid;
-(void)IObDownStatus_DeleteTask;
-(void)IObDownStatus_DeleteTasks;
-(void)IObDownStatus_PauseTask:(unsigned)un_rid;
-(void)IObDownStatus_PauseAllTasks;
-(void)IObDownStatus_StartTask:(unsigned)un_rid;
-(void)IObDownStatus_StartAllTask;
-(void)IObDownStatus_TaskFail:(unsigned)un_rid;
-(void)IObDownStatus_TaskProgress:(unsigned)un_rid:(float)fPercent:(float)fLocalSize:(float)fFileSize;
-(void)IObDownStatus_TaskSpeed:(unsigned)un_rid:(float)fSpeed;
-(void)IObDownStatus_AllTaskFinish;
-(void)IObDownStatus_AddTasksFinish;
-(void)IObDownStatus_LoadDBFinish;
@end

class IObserverDownTaskStatus:public IMessageObserver
{
public:
    //网络状态切换
    virtual void IObDownStatus_AddTask(unsigned un_rid){}
    virtual void IObDownStatus_DownTaskFinish(unsigned un_rid){}
    virtual void IObDownStatus_DeleteTask(){}
    virtual void IObDownStatus_DeleteTasks(){}
    virtual void IObDownStatus_PauseTask(unsigned un_rid){}
    virtual void IObDownStatus_PauseAllTasks(){}
    virtual void IObDownStatus_StartTask(unsigned un_rid){}
    virtual void IObDownStatus_StartAllTask(){}
    virtual void IObDownStatus_TaskFail(unsigned un_rid){}
    virtual void IObDownStatus_TaskProgress(unsigned un_rid, float fPercent, float fLocalSize, float fFileSize){}
    virtual void IObDownStatus_TaskSpeed(unsigned un_rid, float fSpeed){}
    virtual void IObDownStatus_AllTaskFinish(){}
    virtual void IObDownStatus_AddTasksFinish(){}
    virtual void IObDownStatus_LoadDBFinish(){}
    
    enum eumMethod
    {
        DownStatusAddTask,
        DownStatusTaskFinish,
        DownStatusDeleteTask,
        DownStatusDeleteTasks,
        DownStatusPauseTask,
        DownStatusPauseAllTasks,
        DownStatusTaskStart,
        DownStatusTaskAllStart,
        DownStatustaskFail,
        DownStatusTaskProgress,
        DownStatusTaskSpeed,
        DownStatusAllTaskFinish,
        DownStatusAddTasksFinish,
        DownStatusLoadDBFinish
    };
    
    MESSAGE_OBSERVER_NOTIFY_BEGIN(IObserverDownTaskStatus)
    
    NOTIFY_CASE_ITEM(DownStatusAddTask,IObDownStatus_AddTask,_1PARA);
    NOTIFY_CASE_ITEM(DownStatusTaskFinish,IObDownStatus_DownTaskFinish,_1PARA);
    NOTIFY_CASE_ITEM(DownStatusDeleteTask,IObDownStatus_DeleteTask,_0PARA);
    NOTIFY_CASE_ITEM(DownStatusDeleteTasks,IObDownStatus_DeleteTasks,_0PARA);
    NOTIFY_CASE_ITEM(DownStatusPauseTask,IObDownStatus_PauseTask,_1PARA);
    NOTIFY_CASE_ITEM(DownStatusPauseAllTasks,IObDownStatus_PauseAllTasks,_0PARA);
    NOTIFY_CASE_ITEM(DownStatusTaskStart,IObDownStatus_StartTask,_1PARA);
    NOTIFY_CASE_ITEM(DownStatusTaskAllStart, IObDownStatus_StartAllTask, _0PARA);
    NOTIFY_CASE_ITEM(DownStatustaskFail,IObDownStatus_TaskFail,_1PARA);
    NOTIFY_CASE_ITEM(DownStatusTaskProgress,IObDownStatus_TaskProgress,_4PARA);
    NOTIFY_CASE_ITEM(DownStatusTaskSpeed,IObDownStatus_TaskSpeed,_2PARA);
    NOTIFY_CASE_ITEM(DownStatusAllTaskFinish, IObDownStatus_AllTaskFinish, _0PARA);
    NOTIFY_CASE_ITEM(DownStatusAddTasksFinish, IObDownStatus_AddTasksFinish, _0PARA);
    NOTIFY_CASE_ITEM(DownStatusLoadDBFinish, IObDownStatus_LoadDBFinish, _0PARA);
    
    MESSAGE_OBSERVER_NOTIFY_END();
};

#endif
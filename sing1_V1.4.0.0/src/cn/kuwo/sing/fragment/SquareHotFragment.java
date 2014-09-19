package cn.kuwo.sing.fragment;

import java.util.List;

import android.os.Bundle;
import android.support.v4.app.Fragment;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.AdapterView;
import android.widget.AdapterView.OnItemClickListener;
import android.widget.ListView;
import cn.kuwo.sing.R;
import cn.kuwo.sing.bean.MTV;
import cn.kuwo.sing.business.ListBusiness;
import cn.kuwo.sing.context.Constants;
import cn.kuwo.sing.ui.adapter.SquareMtvObjectAdapter;
import cn.kuwo.sing.util.AnimateFirstDisplayListener;
import cn.kuwo.sing.util.PageDataHandler;

import com.handmark.pulltorefresh.library.PullToRefreshBase;
import com.handmark.pulltorefresh.library.PullToRefreshBase.OnRefreshListener;
import com.handmark.pulltorefresh.library.PullToRefreshListView;

public class SquareHotFragment extends Fragment {
	private View mContentView;
	private PullToRefreshListView lvFragmentSquareHot;
	private ListBusiness mListBusiness;
	private SquareMtvObjectAdapter mMtvObjectAdapter;
	private int mCurrentPage = 1;
	
	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
	}
	
	@Override
	public View onCreateView(LayoutInflater inflater, ViewGroup container,
			Bundle savedInstanceState) {
		mContentView = inflater.inflate(R.layout.square_fragment_hot, null);
		return mContentView;
	}
	
	
	@Override
	public void onActivityCreated(Bundle savedInstanceState) {
		super.onActivityCreated(savedInstanceState);
		initData();
		initView();
		obtainData(1);
	}
	
	private void initData() {
		mListBusiness = new ListBusiness();
	}
	
	private void initView() {
		lvFragmentSquareHot = (PullToRefreshListView) getActivity().findViewById(R.id.lvFragmentSquareHot);		
		lvFragmentSquareHot.setOnRefreshListener(new OnRefreshListener<ListView>() {

			@Override
			public void onRefresh(PullToRefreshBase<ListView> refreshView) {
				switch(refreshView.getCurrentMode()){
				case PULL_FROM_START:
					obtainData(1);
					break;
				case PULL_FROM_END:
					obtainData(mCurrentPage+1);
					break;

				default:
					break;
				}
			}
			
		});
		mMtvObjectAdapter = new SquareMtvObjectAdapter(getActivity(), Constants.FLAG_HOT_MTV);
		
	}
	
	private void obtainData(int Page) {
		mListBusiness.getSquareHotSong(Page, 24, new SquarePageDataHandler(Page));
	}
	
	private class SquarePageDataHandler extends PageDataHandler<MTV> {
		private int currentRequestPageNum;
				
		SquarePageDataHandler(int page){
			currentRequestPageNum = page;
		}
		@Override
		public void onSuccess(List<MTV> data) {
//			if (mTop){
//				mMtvObjectAdapter.setTopMtv(data.get(0), true);
//				obtainData(mCurrentPage);
//			}else{
//				if (mCurrentPage == 1){
//					mMtvObjectAdapter.clearImageObjectList();
//				}
//				mMtvObjectAdapter.setImageObjectData(data);
//				lvFragmentSquareHot.setAdapter(mMtvObjectAdapter);
//			}
			mCurrentPage = currentRequestPageNum;
			if (mCurrentPage == 1){
				mMtvObjectAdapter.clearImageObjectList();
			}
			mMtvObjectAdapter.setImageObjectData(data);
			lvFragmentSquareHot.setAdapter(mMtvObjectAdapter);
			lvFragmentSquareHot.onRefreshComplete();
		}
		
		@Override
		public void onFailure(Throwable error, String content) {
//			if (mTop){
//				mMtvObjectAdapter.setTopMtv(null, false);
//			}else{
//				obtainData(mCurrentPage);
//			}
			lvFragmentSquareHot.onRefreshComplete();
		}

	}
	
}
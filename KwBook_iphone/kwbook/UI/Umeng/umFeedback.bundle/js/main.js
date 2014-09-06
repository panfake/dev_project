var CONFIG = (function() {
    var STRINGS = {
        'FORM_BLANK_ALERT': '请输入反馈内容哦!',
        'THANKS': '感谢您的反馈!',
        'NETWORK_ERROR': '网络问题，请稍后再试，本条已经缓存下次自动重发。'
    };

    return {
        get: function(name) { return STRINGS[name]; }
    };
})();

var myScroll;
function loaded() {
	myScroll = new iScroll('wrapper');
}

document.addEventListener('touchmove', function (e) { e.preventDefault(); }, false);

document.addEventListener('DOMContentLoaded', loaded, false);

Date.prototype.format = function(fmt) {
    var o = {
        "M+": this.getMonth() + 1,
        //月份
        "d+": this.getDate(),
        //日
        "h+": this.getHours() % 12 == 0 ? 12 : this.getHours() % 12,
        //小时
        "H+": this.getHours(),
        //小时
        "m+": this.getMinutes(),
        //分
        "s+": this.getSeconds(),
        //秒
        "q+": Math.floor((this.getMonth() + 3) / 3),
        //季度
        "S": this.getMilliseconds() //毫秒
    };
    var week = {
        "0": "\u65e5",
        "1": "\u4e00",
        "2": "\u4e8c",
        "3": "\u4e09",
        "4": "\u56db",
        "5": "\u4e94",
        "6": "\u516d"
    };
    if (/(y+)/.test(fmt)) {
        fmt = fmt.replace(RegExp.$1, (this.getFullYear() + "").substr(4 - RegExp.$1.length));
    }
    if (/(E+)/.test(fmt)) {
        fmt = fmt.replace(RegExp.$1, ((RegExp.$1.length > 1) ? (RegExp.$1.length > 2 ? "\u661f\u671f": "\u5468") : "") + week[this.getDay() + ""]);
    }
    for (var k in o) {
        if (new RegExp("(" + k + ")").test(fmt)) {
            fmt = fmt.replace(RegExp.$1, (RegExp.$1.length == 1) ? (o[k]) : (("00" + o[k]).substr(("" + o[k]).length)));
        }
    }
    return fmt;
}

function getDateTime(){
    var d = new Date();
    return d.format("yyyy-MM-dd HH:mm:ss");
}

//弹出alert view , javascript的alert无法修改标题。
function showAlert(title){
    location.href = 'umengjscall:CallAlert:' + decodeURIComponent(title);
}

function submitForm() {
// result 会作为json 数据发给objC端
    var result = {};
	result.contact = {};
    var content = document.getElementById("content").value;
	var orderType = document.getElementById("order_type").value;
	var orderValue = document.getElementById("order_value").value;
//  var age_group = document.getElementById("age_group").value;
//  var gender = document.getElementById("gender").value;
    var rate = document.getElementById("rate").value;
	
	if (orderType == 1){
		result.contact.qq = orderValue;
	}
	if (orderType == 2){
		result.contact.phone = orderValue;
	}
    result.age_group = '';
    result.gender = '';
	
//  if (!!age_group) {
//      result.age_group = age_group
//  }
//  if (!!gender) {
//      result.gender = gender
//  }


//自定义字段，目前有提供了两个自定义Hash可用
//contact 用于传递联系方式，比如email,qq,phone等
//remark 用于传递备注信息，比如用户名,网址等等
// 参见下面两个例子,这里我们添加了网页表单id为email和user_name
//    var email = document.getElementById("email").value;
//    if (!!email) {
//        result.contact.email = email;
//		  result.contact.qq = qq;
//    }
//    var userName = document.getElementById("user_name").value;
//    if (!!userName) {
//        result.remark.userName = userName;
//    }

    result.remark ={};

    if (!!rate) {
        result.remark.rate = rate
    }
	

    if (content.trim().length > 0) {
        result.content = content.trim();
        result.datetime = getDateTime();
        location.href = 'umengjscall:CallsendReplyumengjscall:' + decodeURIComponent(JSON.stringify(result));
        renderNewFeedback(result);
//        showAlert(CONFIG.get('THANKS'));
    }
    else {
        showAlert(CONFIG.get('FORM_BLANK_ALERT'));
    }

    return false;
}

function initFormValues(values_json){
    var genderValue = values_json.gender;
    $("#gender option[value=" + genderValue + "]")[0].selected = 'selected';

    var ageValue = values_json.age_group;
    $("#age_group option[value=" + ageValue + "]")[0].selected = 'selected';

    var rateValue = values_json.rate;
    $("#rate option[value=" + rateValue + "]")[0].selected = 'selected';
}

$(document).ready(function () {
    $('#cancelUserDashBoard').click(function () {
        $('#userDashBoard').modal('hide');
    });
    $('#backBtn').click(function () {
        location.href = 'umengjscall:dismissumengjscall:';
    });
});


function renderFeedbacks(feedbacks) {
    var template_source = $("#feedbacks").html();
    var template = Handlebars.compile(template_source);
    var html = template(feedbacks);
    $("#topics").append(html);
    if($('#topics').height() > $('#wrapper').height()){
        myScroll.refresh();
        myScroll.scrollToElement("#feedbacks_foot", 10);
    }
    return false;
}

//
function renderNewFeedback(feedback) {
    var template_source = $("#new_feedback").html();
    var template = Handlebars.compile(template_source);
    var html = template(feedback);
    setTimeout(function () {
            $("#topics").append(html);
            if ($('#topics').height() > $('#wrapper').height()) {
                    myScroll.refresh();
                    myScroll.scrollToElement("#feedbacks_foot", 10);
                }
        }
        , 50);

    document.getElementById("content").value = "";

}
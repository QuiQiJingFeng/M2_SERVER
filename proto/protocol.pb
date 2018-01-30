
 
msg/common.proto
msg.common"
Query"+
	Handshake
v1 (	Rv1
v2 (	Rv2")
	Heartbeat
	timestamp (R	timestamp*
Result
success
fail
¹
msg/login.proto	msg.login"o
LoginReq3

login_type (2.msg.login.LoginTypeR	loginType
account (	Raccount
token (	Rtoken"w
LoginRsp)
result (2.msg.login.ResultRresult'
reconnect_token (	RreconnectToken
user_id (	RuserId"
	LogoutReq"6
	LogoutRsp)
result (2.msg.login.ResultRresult*%
	LoginType	
debug
	reconnect*E
Result
success
fail
unknow_login_type
	auth_fail
U
msg/user.protomsg.user"
QueryInfoReq")
QueryInfoRsp
gold_num (RgoldNum
 
protocol.protomsg/common.protomsg/login.protomsg/user.proto"Ÿ
C2S

session_id (R	sessionId3
	handshake
 (2.msg.common.HandshakeR	handshake3
	heartbeat (2.msg.common.HeartbeatR	heartbeat)
login (2.msg.login.LoginReqRlogin,
logout (2.msg.login.LogoutReqRlogout6

query_info‘N (2.msg.user.QueryInfoReqR	queryInfo"¸
S2C

session_id (R	sessionId
is_push (RisPush3
	handshake
 (2.msg.common.HandshakeR	handshake3
	heartbeat (2.msg.common.HeartbeatR	heartbeat)
login (2.msg.login.LoginRspRlogin,
logout (2.msg.login.LogoutRspRlogout6

query_info‘N (2.msg.user.QueryInfoRspR	queryInfo
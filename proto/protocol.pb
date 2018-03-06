
‚
msg/common.proto
msg.common"
Query"+
	Handshake
v1 (	Rv1
v2 (	Rv2"
	Heartbeat*
Result
success
fail
Ï
msg/login.proto	msg.login"o
LoginReq3

login_type (2.msg.login.LoginTypeR	loginType
account (	Raccount
token (	Rtoken"w
LoginRsp)
result (2.msg.login.ResultRresult'
reconnect_token (	RreconnectToken
user_id (	RuserId"
	LogoutReq"6
	LogoutRsp)
result (2.msg.login.ResultRresult*%
	LoginType	
debug
	reconnect*[
Result
success
fail
unknow_login_type
	auth_fail
create_user_name
¦
msg/user.protomsg.user"@
UserInfo
user_id (	RuserId
	user_name (	RuserName"
QueryInfoReq")
QueryInfoRsp
gold_num (RgoldNum"
CreateRoomReq"n
CreateRoomRsp
result (	Rresult
room_id (RroomId,
players (2.msg.user.UserInfoRplayers"
PushTest
msg (	Rmsg"X
RefreshRoomInfo
room_id (RroomId,
players (2.msg.user.UserInfoRplayers"&
JoinRoomReq
room_id (RroomId"l
JoinRoomRsp
result (	Rresult
room_id (RroomId,
players (2.msg.user.UserInfoRplayers
Ø
protocol.protomsg/common.protomsg/login.protomsg/user.proto"×
C2S

session_id (R	sessionId3
	handshake
 (2.msg.common.HandshakeR	handshake3
	heartbeat (2.msg.common.HeartbeatR	heartbeat)
login (2.msg.login.LoginReqRlogin,
logout (2.msg.login.LogoutReqRlogout9
create_room‘N (2.msg.user.CreateRoomReqR
createRoom3
	join_room“N (2.msg.user.JoinRoomReqRjoinRoom"¸
S2C

session_id (R	sessionId
is_push (RisPush3
	handshake
 (2.msg.common.HandshakeR	handshake3
	heartbeat (2.msg.common.HeartbeatR	heartbeat)
login (2.msg.login.LoginRspRlogin,
logout (2.msg.login.LogoutRspRlogout9
create_room‘N (2.msg.user.CreateRoomRspR
createRoomF
refresh_room_info’N (2.msg.user.RefreshRoomInfoRrefreshRoomInfo3
	join_room“N (2.msg.user.JoinRoomRspRjoinRoom
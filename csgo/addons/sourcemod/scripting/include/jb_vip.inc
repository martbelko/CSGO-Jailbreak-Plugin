#if defined JB_VIP_INC
 #endinput
#endif
#define JB_VIP_INC

enum VipMode
{
	VM_None = 0,
	VM_Vip,
	VM_ExtraVip
}

native bool IsClientVip(int client);
native bool IsClientExtraVip(int client);

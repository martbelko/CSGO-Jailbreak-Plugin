// © Maxim "Kailo" Telezhenko, 2017
// Version 2

// Struct of valist
// int arg_count;	// 0
// int location;	// 1
// int iterator;	// 2
// total:			// 3
enum
{
	m_arg_count = 0,
	m_location = 1,
	m_iterator = 2,
};

// Global anchor for memory access
stock static int g_anchor[1] = 1337; // =)

// Allow to get variable local address in plugin memory
stock static int GetAddr(any[] array)
{
	int anchor[1];
	return GetAddrWorker(anchor, array);
}

// "any ..." needed for escape warning "symbol is never used" in previous function
stock static int GetAddrWorker(int[] anchor, any ...)
{
	return anchor[4];
}

stock static void GetOldFrameBase(int[] anchor)
{
	anchor[0] = anchor[2];
}

// Allow to get value form plugin memory (DAT, heap, stack) with local address
stock static int Deref(int local_addr)
{
	return DerefWorker(g_anchor, local_addr);
}

// Will throw error if anchor_addr bigger than local_addr
// Therefore: valist must be included first for lower anchor_addr
stock static int DerefWorker(int[] anchor, int local_addr)
{
	static int anchor_addr = -1;
	if (anchor_addr == -1)
	{
		anchor_addr = GetAddr(g_anchor);
	}
	return anchor[(local_addr - anchor_addr) / 4];
}

#define THIS (view_as<ArrayList>(this))
#define member_set(%0,%1,%2) %0.Set(0, %2, %1, false)
#define member_get(%0,%1) %0.Get(0, %1, false)
methodmap Valist
{
	property int arg_count
	{
		public get() { return member_get(THIS,m_arg_count); }
	}

	public Valist(int param_n)
	{
		int anchor[1];
		GetOldFrameBase(anchor); // result stored in anchor[0]
		ArrayList base = new ArrayList(3, 1);
		member_set(base,m_arg_count,Deref(anchor[0] + 8));
		member_set(base,m_location,anchor[0] + 12);
		member_set(base,m_iterator,param_n);
		return view_as<Valist>(base);
	}

	public void Close()
	{
		THIS.Close();
	}

	public any Arg()
	{
		int iterator = member_get(THIS,m_iterator);
		if (iterator > member_get(THIS,m_arg_count))
			ThrowError("End of parameters reached.");
		member_set(THIS,m_iterator,iterator + 1);
		return Deref(Deref(member_get(THIS,m_location) + (iterator - 1) * 4));
	}

	public bool More()
	{
		return member_get(THIS,m_iterator) <= member_get(THIS,m_arg_count);
	}
}
#undef THIS

#define va_start(%0) Valist VALIST = Valist(%0)

// if have more args to read
#define va_more() VALIST.More()

#define va_arg() VALIST.Arg()

#define va_args() VALIST.arg_count

// Must called when list no more needed
#define va_end() VALIST.Close()
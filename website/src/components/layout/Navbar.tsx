import Link from 'next/link';
import Image from 'next/image';

export function Navbar() {
    return (
        <nav className="fixed top-0 left-0 w-full z-50 py-6 px-8 flex justify-between items-center mix-blend-difference text-white">
            <div className="flex items-center">
                <Image src="/logo/Zuralog.png" alt="Zuralog" width={120} height={40} className="h-8 w-auto invert" />
            </div>

            <div className="hidden md:flex gap-8 text-sm font-medium">
                <Link href="#features" className="hover:opacity-70 transition-opacity">Features</Link>
                <Link href="#apps" className="hover:opacity-70 transition-opacity">Health Apps</Link>
                <Link href="#support" className="hover:opacity-70 transition-opacity">Support</Link>
            </div>

            <button className="bg-white text-black px-6 py-2 rounded-full text-sm font-semibold hover:-translate-y-0.5 transition-transform shadow-md">
                Waitlist Now
            </button>
        </nav>
    );
}

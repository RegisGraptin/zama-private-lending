import { ConnectButton } from "@rainbow-me/rainbowkit";
import Link from "next/link";

export default function Header() {
  return (
    <>
      <nav className="block w-full max-w-screen-lg px-4 py-2 mx-auto text-white shadow lg:px-8 lg:py-3 z-[9999] rounded">
        <div className="container flex flex-wrap items-center justify-between mx-auto mt-5">
          <Link
            href="/"
            className="mr-4 block cursor-pointer py-1.5 text-base font-semibold"
          >
            {process.env.NEXT_PUBLIC_SITE_NAME}
          </Link>

          <ConnectButton />

          <button
            className="relative ml-auto h-6 max-h-[40px] w-6 max-w-[40px] select-none rounded-lg text-center align-middle text-xs font-medium uppercase text-inherit transition-all hover:bg-transparent focus:bg-transparent active:bg-transparent disabled:pointer-events-none disabled:opacity-50 disabled:shadow-none lg:hidden"
            type="button"
          >
            <span className="absolute transform -translate-x-1/2 -translate-y-1/2 top-1/2 left-1/2">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                className="w-6 h-6"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  d="M4 6h16M4 12h16M4 18h16"
                ></path>
              </svg>
            </span>
          </button>
        </div>
      </nav>
    </>
  );
}

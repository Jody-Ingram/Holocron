import type {Metadata} from "next";
import "./globals.css";
export const metadata:Metadata={title:"Wellstar AVD Director",description:"Unified Azure Virtual Desktop operations dashboard for sessions, hosts, and Insights.",icons:{icon:"/favicon.svg"}};
export default function RootLayout({children}:{children:React.ReactNode}){return <html lang="en"><body>{children}</body></html>}

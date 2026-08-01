// @ts-nocheck
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { AwsClient } from "https://esm.sh/aws4fetch@1.0.17"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { file, ext, folder } = await req.json()
    if (!file || !ext) {
      throw new Error("Missing 'file' (base64) or 'ext'")
    }

    // Decode base64
    const binaryStr = atob(file)
    const len = binaryStr.length
    const bytes = new Uint8Array(len)
    for (let i = 0; i < len; i++) {
      bytes[i] = binaryStr.charCodeAt(i)
    }

    const fileName = `${crypto.randomUUID()}${ext}`
    const objectKey = folder ? `${folder}/${fileName}` : fileName
    
    const accountId = Deno.env.get('R2_ACCOUNT_ID')
    const accessKeyId = Deno.env.get('R2_ACCESS_KEY_ID')
    const secretAccessKey = Deno.env.get('R2_SECRET_ACCESS_KEY')
    const bucketName = Deno.env.get('R2_BUCKET_NAME') || 'street-eats-images'
    const publicUrl = Deno.env.get('R2_PUBLIC_URL')

    if (!accountId || !accessKeyId || !secretAccessKey) {
      throw new Error("Server configuration missing R2 credentials")
    }

    const url = `https://${accountId}.r2.cloudflarestorage.com/${bucketName}/${objectKey}`

    const aws = new AwsClient({
      accessKeyId,
      secretAccessKey,
      service: 's3',
      region: 'auto',
    })

    const getContentType = (e: string) => {
      const eLower = e.toLowerCase()
      if (eLower === '.jpg' || eLower === '.jpeg') return 'image/jpeg'
      if (eLower === '.png') return 'image/png'
      if (eLower === '.webp') return 'image/webp'
      return 'application/octet-stream'
    }

    const response = await aws.fetch(url, {
      method: 'PUT',
      headers: { 'Content-Type': getContentType(ext) },
      body: bytes
    })

    if (response.ok) {
      return new Response(
        JSON.stringify({ url: `${publicUrl}/${objectKey}` }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    } else {
      throw new Error(`R2 failed: ${response.status} ${await response.text()}`)
    }
  } catch (error: any) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    )
  }
})
